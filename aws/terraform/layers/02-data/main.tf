# Layer 2: Data
# This layer sets up data services:
# - MongoDB Atlas for document database
# - Amazon MQ for RabbitMQ message queue

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.14"
    }
  }
}

# Data source for networking layer outputs
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "${path.module}/../00-networking/terraform.tfstate"
  }
}

module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  environment             = var.environment
  mongodb_org_id          = var.mongodb_org_id
  mongodb_version         = var.mongodb_version
  mongodb_major_version   = var.mongodb_major_version
  instance_size_name      = var.mongodb_instance_size
  mongodb_region          = var.mongodb_region
  disk_size_gb            = var.mongodb_disk_size_gb
  vpc_cidr                = data.terraform_remote_state.networking.outputs.vpc_cidr
  database_username       = var.mongodb_username
  database_password       = var.mongodb_password
  enable_private_endpoint = var.mongodb_enable_private_endpoint
  enable_outage_test      = var.mongodb_enable_outage_test
}

module "amazon_mq" {
  source = "../../modules/amazon-mq"

  environment                 = var.environment
  vpc_id                      = data.terraform_remote_state.networking.outputs.vpc_id
  vpc_cidr                    = data.terraform_remote_state.networking.outputs.vpc_cidr
  subnet_ids                  = data.terraform_remote_state.networking.outputs.private_subnets
  eks_nodes_security_group_id = data.terraform_remote_state.networking.outputs.eks_nodes_security_group_id

  rabbitmq_version = var.rabbitmq_version
  instance_type    = var.mq_instance_type
  deployment_mode  = var.mq_deployment_mode
  admin_username   = var.mq_admin_username
  admin_password   = var.mq_admin_password

  mq_ingress_rules = [
    {
      from_port       = 5672
      to_port         = 5672
      protocol        = "tcp"
      security_groups = [data.terraform_remote_state.networking.outputs.eks_nodes_security_group_id]
      description     = "RabbitMQ AMQP"
    },
    {
      from_port   = 15672
      to_port     = 15672
      protocol    = "tcp"
      cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
      description = "RabbitMQ Management UI"
    },
    {
      from_port       = 5671
      to_port         = 5671
      protocol        = "tcp"
      security_groups = [data.terraform_remote_state.networking.outputs.eks_nodes_security_group_id]
      description     = "RabbitMQ AMQPS (TLS)"
    }
  ]

  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  log_retention_days     = var.log_retention_days
  queue_depth_threshold  = var.queue_depth_threshold
  max_connections        = var.mq_max_connections
  channel_max            = var.mq_channel_max

  tags = local.common_tags
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Data"
    }
  )
}
