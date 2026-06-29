# Layer 4: Observability
# This layer sets up monitoring and observability:
# - CloudWatch Log Groups
# - CloudWatch Alarms
# - SNS topics for notifications
# - CloudWatch Dashboard

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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
