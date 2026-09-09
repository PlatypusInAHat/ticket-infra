terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Layer       = "03-storage"
      Owner       = lookup(var.tags, "Owner", "platform")
      CostCenter  = lookup(var.tags, "CostCenter", "ticketstage")
    })
  }
}
