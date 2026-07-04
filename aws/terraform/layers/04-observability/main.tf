# Layer 4: Observability
# This layer sets up monitoring and observability:
# - CloudWatch Log Groups
# - CloudWatch Alarms
# - SNS topics for notifications
# - CloudWatch Dashboard
# - kube-prometheus-stack for in-cluster metrics and alerting

data "terraform_remote_state" "kubernetes" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/01-kubernetes/terraform.tfstate"
    region = var.terraform_state_region
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment        = var.environment
  aws_region         = var.aws_region
  log_retention_days = var.log_retention_days
  alert_email        = var.alert_email

  tags = local.common_tags
}

resource "random_password" "grafana_admin" {
  length  = 24
  special = true

  override_special = "_%@#-+"
}

resource "aws_secretsmanager_secret" "grafana_admin_password" {
  name_prefix             = "${var.environment}/monitoring/grafana-admin-"
  description             = "Grafana admin password for ${var.environment}"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "grafana_admin_password" {
  secret_id     = aws_secretsmanager_secret.grafana_admin_password.id
  secret_string = random_password.grafana_admin.result
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.kubernetes.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.kubernetes.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.kubernetes.outputs.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.kubernetes.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.kubernetes.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.kubernetes.outputs.cluster_id]
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  values = [file("${path.module}/../../../../monitoring/kube-prometheus-stack-values.yaml")]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = random_password.grafana_admin.result
  }
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Observability"
    }
  )
}
