# Staging Environment Configuration
# File: infra/aws/terraform/environments/staging/terraform.tfvars

environment = "staging"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr        = "10.1.0.0/16"
public_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnets = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# ALB Configuration
alb_enable_deletion_protection = true
enable_https                   = true
# acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/..."

# EKS Configuration
kubernetes_version = "1.29"

# System Node Group (on-demand)
system_node_group_desired_size   = 2
system_node_group_min_size       = 1
system_node_group_max_size       = 3
system_node_group_instance_types = ["t4g.large"]

# App Node Group (spot)
app_spot_node_group_desired_size   = 2
app_spot_node_group_min_size       = 2
app_spot_node_group_max_size       = 5
app_spot_node_group_instance_types = ["t4g.large", "m7g.large"]

# MongoDB Atlas
mongodb_version                 = "7.0"
mongodb_major_version           = "7.0"
mongodb_instance_size           = "M20"
mongodb_region                  = "us-east-1"
mongodb_disk_size_gb            = 50
mongodb_database                = "ticket_booking_staging"
mongodb_enable_private_endpoint = true
enable_cloudwatch_logs          = true
log_retention_days              = 14

# RabbitMQ
rabbitmq_version   = "3.12.13"
mq_instance_type   = "mq.m5.large"
mq_deployment_mode = "ACTIVE_STANDBY_MULTI_AZ"
mq_max_connections = 5000

# CloudFront
cloudfront_cache_default_ttl = 3600
enable_api_cache_behavior    = true
invalidate_on_apply          = false

# Monitoring
alert_email = "ops-staging@example.com"

# Project
project_name = "TicketBooking"

# Additional Tags
tags = {
  Environment = "staging"
  CostCenter  = "engineering"
  ManagedBy   = "Terraform"
}
