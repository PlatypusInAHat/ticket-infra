<#
.SYNOPSIS
  Bring a whole TicketStage environment up or down with one command.

.DESCRIPTION
  up:
    1. terraform init + apply layers 00-networking .. 04-observability
    2. update kubeconfig for <env>-eks
    3. create/refresh Secret ticketstage-secrets from k8s/secrets/<env>.env
       (generated on first run from Terraform outputs + TF_VAR_* credentials)
    4. install Argo CD and register the Application for this environment

  down:
    1. delete the Argo CD Application and the Ingress so the AWS Load Balancer
       Controller removes the ALB (otherwise VPC destroy hangs on its ENIs)
    2. terraform destroy 04 -> 02 -> 01 -> 00
       03-storage (ECR images, S3/CloudFront, Secrets Manager) is kept unless
       -IncludeStorage; it costs almost nothing while idle.

  Requires: terraform, aws, kubectl on PATH; AWS credentials; TF_STATE_BUCKET,
  TF_STATE_REGION, TF_LOCK_TABLE; and the TF_VAR_* values listed in README.md.

.EXAMPLE
  pwsh ./scripts/stack.ps1 -Action up -Environment dev
  pwsh ./scripts/stack.ps1 -Action down -Environment dev -AutoApprove
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("up", "down", "status")]
  [string]$Action,

  [ValidateSet("dev", "staging", "prod")]
  [string]$Environment = "dev",

  # Skip Terraform's interactive "yes" prompts.
  [switch]$AutoApprove,

  # down: also destroy 03-storage (ECR repositories and images, S3, CloudFront, Secrets Manager).
  [switch]$IncludeStorage,

  # down: keep 00-networking and 02-data (Atlas + Amazon MQ live in the VPC), destroy only the cluster.
  [switch]$KeepData,

  # Argo CD release installed by "up".
  [string]$ArgoCdVersion = "v2.13.3"
)

$ErrorActionPreference = "Stop"

$infraRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformRoot = Join-Path $infraRoot "aws\terraform"
$varFile = Join-Path $terraformRoot "environments\$Environment\terraform.tfvars"
$secretsFile = Join-Path $infraRoot "k8s\secrets\$Environment.env"
$applyLayers = @("00-networking", "01-kubernetes", "02-data", "03-storage", "04-observability")

function Invoke-Native {
  param([string]$File, [string[]]$Arguments)
  & $File @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$File $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Assert-Prerequisites {
  foreach ($tool in @("terraform", "aws", "kubectl")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
      throw "'$tool' is not on PATH."
    }
  }
  foreach ($name in @("TF_STATE_BUCKET", "TF_STATE_REGION", "TF_LOCK_TABLE")) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
      throw "$name is required (Terraform remote state)."
    }
  }
  # Layers read each other's state through these variables.
  $env:TF_VAR_terraform_state_bucket = $env:TF_STATE_BUCKET
  $env:TF_VAR_terraform_state_region = $env:TF_STATE_REGION
  if (-not (Test-Path $varFile)) {
    throw "tfvars not found: $varFile"
  }
}

function Get-AwsRegion {
  $line = Select-String -Path $varFile -Pattern '^\s*aws_region\s*=\s*"([^"]+)"' | Select-Object -First 1
  if (-not $line) {
    throw "aws_region not found in $varFile"
  }
  return $line.Matches[0].Groups[1].Value
}

function Initialize-Layer {
  param([string]$Layer)
  & (Join-Path $terraformRoot "scripts\init-layer.ps1") -Environment $Environment -Layer $Layer -SkipValidate
}

function Invoke-TerraformLayer {
  param([string]$Layer, [ValidateSet("apply", "destroy")][string]$Command)
  Initialize-Layer -Layer $Layer
  $layerDir = Join-Path $terraformRoot "layers\$Layer"
  $tfArgs = @("-chdir=$layerDir", $Command, "-var-file=$varFile", "-input=false")
  if ($AutoApprove) {
    $tfArgs += "-auto-approve"
  }
  Write-Host "==> terraform $Command $Layer" -ForegroundColor Cyan
  Invoke-Native -File "terraform" -Arguments $tfArgs
}

function Get-TerraformOutput {
  param([string]$Layer, [string]$Name)
  $layerDir = Join-Path $terraformRoot "layers\$Layer"
  $value = & terraform "-chdir=$layerDir" output -raw $Name
  if ($LASTEXITCODE -ne 0) {
    throw "terraform output $Name ($Layer) failed"
  }
  return ($value -join "").Trim()
}

function Update-Kubeconfig {
  Initialize-Layer -Layer "01-kubernetes"
  $cluster = Get-TerraformOutput -Layer "01-kubernetes" -Name "cluster_id"
  Invoke-Native -File "aws" -Arguments @("eks", "update-kubeconfig", "--name", $cluster, "--region", (Get-AwsRegion))
}

function New-RandomSecret {
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes)
  $rng.Dispose()
  return (($bytes | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-RequiredEnv {
  param([string]$Name)
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$Name is required to generate $secretsFile (or create that file yourself)."
  }
  return $value
}

# Generated once and then reused: rotating SECRET_HASH_KEY or PASSWORD_PEPPER
# invalidates every stored pass hash / password, so never regenerate blindly.
function New-RuntimeSecretsFile {
  Write-Host "==> generating $secretsFile" -ForegroundColor Cyan

  $mongoHost = Get-TerraformOutput -Layer "02-data" -Name "mongodb_srv_host"
  $mongoUser = [uri]::EscapeDataString((Get-RequiredEnv "TF_VAR_mongodb_username"))
  $mongoPass = [uri]::EscapeDataString((Get-RequiredEnv "TF_VAR_mongodb_password"))
  $mqEndpoint = Get-TerraformOutput -Layer "02-data" -Name "mq_amqp_endpoint"
  $mqUser = [uri]::EscapeDataString((Get-RequiredEnv "TF_VAR_mq_admin_username"))
  $mqPass = [uri]::EscapeDataString((Get-RequiredEnv "TF_VAR_mq_admin_password"))

  $mongoUri = {
    param([string]$Database)
    "mongodb+srv://${mongoUser}:${mongoPass}@${mongoHost}/${Database}?retryWrites=true&w=majority&authSource=admin"
  }

  $lines = @(
    "# Generated by scripts/stack.ps1 on $(Get-Date -Format s). Not committed (see .gitignore).",
    "# Add VNPAY_*, MOMO_*, EMAIL_*/SES_SMTP_* and TURNSTILE_SECRET_KEY here (see k8s/base/secrets.example.yaml), then rerun 'up'.",
    "JWT_SECRET=$(New-RandomSecret)",
    "INTERNAL_API_KEY=$(New-RandomSecret)",
    "SECRET_HASH_KEY=$(New-RandomSecret)",
    "PASSWORD_PEPPER=$(New-RandomSecret)",
    "DEVICE_FINGERPRINT_SECRET=$(New-RandomSecret)",
    "WAITING_ROOM_TOKEN_SECRET=$(New-RandomSecret)",
    "PASSWORD_HASH_ROUNDS=12",
    "MIN_PASSWORD_LENGTH=8",
    "AUTH_MONGODB_URI=$(& $mongoUri 'ticket-auth')",
    "CATALOG_MONGODB_URI=$(& $mongoUri 'ticket-catalog')",
    "BOOKING_MONGODB_URI=$(& $mongoUri 'ticket-booking')",
    "CHECKIN_MONGODB_URI=$(& $mongoUri 'ticket-checkin')",
    "NOTIFICATION_MONGODB_URI=$(& $mongoUri 'ticket-notification')",
    "EVENT_BROKER_URL=$($mqEndpoint -replace '^amqps://', "amqps://${mqUser}:${mqPass}@")"
  )

  # waiting-room-service needs Redis; layer 02-data creates ElastiCache only with enable_redis = true.
  if ((Get-TerraformOutput -Layer "02-data" -Name "redis_enabled") -eq "true") {
    $lines += "REDIS_URL=$(Get-TerraformOutput -Layer "02-data" -Name "redis_url")"
  } else {
    $lines += "# REDIS_URL not set: enable_redis = false, so waiting-room-service will stay unready."
  }

  New-Item -ItemType Directory -Force -Path (Split-Path $secretsFile) | Out-Null
  # kubectl --from-env-file breaks on a UTF-8 BOM, which Set-Content adds on Windows PowerShell.
  [System.IO.File]::WriteAllLines($secretsFile, $lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Sync-RuntimeSecret {
  if (-not (Test-Path $secretsFile)) {
    New-RuntimeSecretsFile
  } else {
    Write-Host "==> reusing $secretsFile" -ForegroundColor Cyan
  }

  # --from-env-file does not skip comments, so strip them into a temp file.
  $tempFile = [System.IO.Path]::GetTempFileName()
  try {
    $content = Get-Content $secretsFile | Where-Object { $_ -match '^\s*[A-Za-z_][A-Za-z0-9_]*=' }
    [System.IO.File]::WriteAllLines($tempFile, [string[]]$content, (New-Object System.Text.UTF8Encoding($false)))

    Invoke-Native -File "kubectl" -Arguments @("apply", "-f", (Join-Path $infraRoot "k8s\base\namespace.yaml"))
    $manifest = & kubectl create secret generic ticketstage-secrets --namespace ticketstage "--from-env-file=$tempFile" --dry-run=client -o yaml
    if ($LASTEXITCODE -ne 0) {
      throw "kubectl create secret failed"
    }
    $manifest | & kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
      throw "kubectl apply secret failed"
    }
  } finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
  }
}

function Install-ArgoCd {
  Write-Host "==> installing Argo CD $ArgoCdVersion" -ForegroundColor Cyan
  $namespace = & kubectl create namespace argocd --dry-run=client -o yaml
  $namespace | & kubectl apply -f -
  if ($LASTEXITCODE -ne 0) {
    throw "creating namespace argocd failed"
  }

  # Server-side apply: the Argo CD CRDs exceed the client-side annotation size limit.
  Invoke-Native -File "kubectl" -Arguments @(
    "apply", "--server-side", "--force-conflicts", "-n", "argocd",
    "-f", "https://raw.githubusercontent.com/argoproj/argo-cd/$ArgoCdVersion/manifests/install.yaml"
  )
  Invoke-Native -File "kubectl" -Arguments @("-n", "argocd", "rollout", "status", "deploy/argocd-server", "--timeout=5m")
  Invoke-Native -File "kubectl" -Arguments @("-n", "argocd", "rollout", "status", "deploy/argocd-repo-server", "--timeout=5m")

  # Each cluster gets the shared AppProject plus only its own root Application;
  # the root then creates ticketstage-<env> from argocd/applications/<env>.
  $bootstrapDir = Join-Path $infraRoot "argocd\bootstrap"
  Invoke-Native -File "kubectl" -Arguments @("apply", "-f", (Join-Path $bootstrapDir "ticketstage-project.yaml"))
  Invoke-Native -File "kubectl" -Arguments @("apply", "-f", (Join-Path $bootstrapDir "$(Get-RootApplicationName).yaml"))
}

function Get-RootApplicationName {
  if ($Environment -eq "dev") {
    return "ticketstage-root"
  }
  return "ticketstage-root-$Environment"
}

function Remove-ClusterWorkloads {
  & kubectl get namespace argocd *> $null
  if ($LASTEXITCODE -eq 0) {
    # Delete the root first: while it exists, auto-sync recreates the child app.
    # The resources finalizers cascade root -> ticketstage-<env> -> every workload, including the Ingress.
    $rootName = Get-RootApplicationName
    Write-Host "==> deleting Argo CD applications $rootName and ticketstage-$Environment" -ForegroundColor Cyan
    & kubectl -n argocd delete application $rootName --ignore-not-found --wait --timeout=10m
    & kubectl -n argocd delete application "ticketstage-$Environment" --ignore-not-found --wait --timeout=10m
  }

  & kubectl get namespace ticketstage *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "==> deleting Ingress (waits for the ALB to be removed)" -ForegroundColor Cyan
    & kubectl -n ticketstage delete ingress --all --wait --timeout=10m
    if ($LASTEXITCODE -ne 0) {
      throw "Ingress deletion did not finish; the ALB may still exist. Check the AWS console before destroying the VPC."
    }
  }
}

function Show-Status {
  foreach ($layer in $applyLayers) {
    Initialize-Layer -Layer $layer | Out-Null
    $resources = & terraform "-chdir=$(Join-Path $terraformRoot "layers\$layer")" state list 2>$null
    $count = @($resources | Where-Object { $_ }).Count
    Write-Host ("{0,-18} {1,4} resources" -f $layer, $count)
  }
}

Assert-Prerequisites
Push-Location $infraRoot
try {
  switch ($Action) {
    "up" {
      foreach ($layer in $applyLayers) {
        Invoke-TerraformLayer -Layer $layer -Command "apply"
      }
      Update-Kubeconfig
      Sync-RuntimeSecret
      Install-ArgoCd

      Write-Host ""
      Write-Host "Environment '$Environment' is up." -ForegroundColor Green
      Write-Host "  ALB hostname (a few minutes after first sync):"
      Write-Host "    kubectl -n ticketstage get ingress ticketstage-api"
      Write-Host "  Argo CD admin password:"
      Write-Host "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'  (base64)"
      Write-Host "  Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
    }
    "down" {
      Update-Kubeconfig
      Remove-ClusterWorkloads

      $destroyLayers = @("04-observability")
      if ($IncludeStorage) {
        $destroyLayers += "03-storage"
      }
      if ($KeepData) {
        $destroyLayers += "01-kubernetes"
      } else {
        $destroyLayers += @("02-data", "01-kubernetes", "00-networking")
      }

      $cluster = Get-TerraformOutput -Layer "01-kubernetes" -Name "cluster_id"
      foreach ($layer in $destroyLayers) {
        Invoke-TerraformLayer -Layer $layer -Command "destroy"
      }

      # EKS recreates its control-plane log group while the cluster is being deleted;
      # remove it so the next "up" does not inherit old logs (and retention cost).
      & aws logs delete-log-group --log-group-name "/aws/eks/$cluster/cluster" --region (Get-AwsRegion) 2>$null

      Write-Host ""
      Write-Host "Environment '$Environment' is down. Destroyed: $($destroyLayers -join ', ')" -ForegroundColor Green
    }
    "status" {
      Show-Status
    }
  }
} finally {
  Pop-Location
}
