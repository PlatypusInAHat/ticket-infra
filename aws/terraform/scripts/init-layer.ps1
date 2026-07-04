param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("dev", "staging", "prod")]
  [string]$Environment,

  [Parameter(Mandatory = $true)]
  [ValidateSet("00-networking", "01-kubernetes", "02-data", "03-storage", "04-observability", "all")]
  [string]$Layer,

  [string]$StateBucket = $env:TF_STATE_BUCKET,
  [string]$StateRegion = $env:TF_STATE_REGION,
  [string]$LockTable = $env:TF_LOCK_TABLE,
  [switch]$SkipValidate
)

$ErrorActionPreference = "Stop"

$layers = if ($Layer -eq "all") {
  @("00-networking", "01-kubernetes", "02-data", "03-storage", "04-observability")
} else {
  @($Layer)
}

if ([string]::IsNullOrWhiteSpace($StateBucket)) {
  throw "TF_STATE_BUCKET is required. Pass -StateBucket or set TF_STATE_BUCKET."
}

if ([string]::IsNullOrWhiteSpace($StateRegion)) {
  throw "TF_STATE_REGION is required. Pass -StateRegion or set TF_STATE_REGION."
}

if ([string]::IsNullOrWhiteSpace($LockTable)) {
  throw "TF_LOCK_TABLE is required. Pass -LockTable or set TF_LOCK_TABLE."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$terraformRoot = Resolve-Path (Join-Path $scriptRoot "..")
$envVarFile = Join-Path $terraformRoot "environments\$Environment\terraform.tfvars"

if (-not (Test-Path $envVarFile)) {
  throw "Environment tfvars not found: $envVarFile"
}

foreach ($layer in $layers) {
  $layerDir = Join-Path $terraformRoot "layers\$layer"

  if (-not (Test-Path $layerDir)) {
    throw "Layer directory not found: $layerDir"
  }

  Write-Host "::group::Terraform init $layer"
  Push-Location $layerDir
  try {
    terraform init `
      -backend-config="bucket=$StateBucket" `
      -backend-config="key=$Environment/$layer/terraform.tfstate" `
      -backend-config="region=$StateRegion" `
      -backend-config="dynamodb_table=$LockTable" `
      -backend-config="encrypt=true"

    if (-not $SkipValidate) {
      terraform validate
    }
  } finally {
    Pop-Location
    Write-Host "::endgroup::"
  }
}
