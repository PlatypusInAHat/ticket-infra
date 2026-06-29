# Development Environment Configuration
# File: infra/aws/terraform/environments/dev/terraform.tfvars

environment = "dev"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

# EKS Configuration
kubernetes_version = "1.29"

# System Node Group (on-demand for reliability)
system_node_group_desired_size   = 1
system_node_group_min_size       = 1
system_node_group_max_size       = 2
system_node_group_instance_types = ["t4g.medium"]

# App Node Group (spot for cost optimization)
app_spot_node_group_desired_size   = 1
app_spot_node_group_min_size       = 1
app_spot_node_group_max_size       = 3
app_spot_node_group_instance_types = ["t4g.medium"]

# MongoDB Atlas
# NOTE: Set these as environment variables or in terraform.tfvars.local
# mongodb_public_key = "..."
# mongodb_private_key = "..."
# mongodb_org_id = "..."
# mongodb_username = "..."
# mongodb_password = "..."

mongodb_version        = "7.0"
mongodb_major_version  = "7.0"
mongodb_instance_size  = "M10"
mongodb_region         = "us-east-1"
mongodb_disk_size_gb   = 10
mongodb_database       = "ticket_booking"
enable_cloudwatch_logs = true
log_retention_days     = 7

# RabbitMQ
# mq_admin_username = "..."
# mq_admin_password = "..."

rabbitmq_version   = "3.12.13"
mq_instance_type   = "mq.t3.micro"
mq_deployment_mode = "SINGLE_INSTANCE"

# CloudFront
cloudfront_cache_default_ttl = 3600
enable_api_cache_behavior    = false

# Monitoring
alert_email = "your-email@example.com"

# Project
project_name = "TicketBooking"

# Additional Tags
tags = {
  Environment = "dev"
  CostCenter  = "engineering"
  ManagedBy   = "Terraform"
}
