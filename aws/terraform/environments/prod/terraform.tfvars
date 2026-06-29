# Production Environment Configuration
# File: infra/aws/terraform/environments/prod/terraform.tfvars

environment = "prod"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr        = "10.2.0.0/16"
public_subnets  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnets = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]

# ALB Configuration
alb_enable_deletion_protection = true
enable_https                   = true
# acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/..."

# EKS Configuration
kubernetes_version = "1.29"

# System Node Group (on-demand)
system_node_group_desired_size   = 2
system_node_group_min_size       = 2
system_node_group_max_size       = 4
system_node_group_instance_types = ["t4g.large"]

# App Node Group (spot + on-demand mix)
app_spot_node_group_desired_size   = 3
app_spot_node_group_min_size       = 3
app_spot_node_group_max_size       = 10
app_spot_node_group_instance_types = ["t4g.large", "m7g.large", "m7g.xlarge"]

# MongoDB Atlas
mongodb_version                 = "7.0"
mongodb_major_version           = "7.0"
mongodb_instance_size           = "M30"
mongodb_region                  = "us-east-1"
mongodb_disk_size_gb            = 100
mongodb_database                = "ticket_booking_prod"
mongodb_enable_private_endpoint = true
mongodb_enable_outage_test      = false
enable_cloudwatch_logs          = true
log_retention_days              = 30

# RabbitMQ
rabbitmq_version      = "3.12.13"
mq_instance_type      = "mq.m5.xlarge"
mq_deployment_mode    = "ACTIVE_STANDBY_MULTI_AZ"
mq_max_connections    = 10000
queue_depth_threshold = 50

# CloudFront
cloudfront_cache_default_ttl = 86400
enable_api_cache_behavior    = true
invalidate_on_apply          = false

# ECR
enable_image_scanning = true

# Monitoring
alert_email = "ops-prod@example.com"

# Project
project_name = "TicketBooking"

# Additional Tags
tags = {
  Environment = "prod"
  CostCenter  = "operations"
  ManagedBy   = "Terraform"
}
