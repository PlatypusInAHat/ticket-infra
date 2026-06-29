# Production Environment Configuration (Trial/Cost-Optimized)
# File: infra/aws/terraform/environments/prod/terraform.tfvars

environment = "prod"
aws_region  = "us-east-1"
project_name = "TicketBooking"

# VPC Configuration (Minimizing to 2 AZs for ALB requirement -> 2 NAT Gateways)
vpc_cidr        = "10.2.0.0/16"
public_subnets = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnets = ["10.2.11.0/24", "10.2.12.0/24"]

# ALB Configuration
alb_enable_deletion_protection = false # Easier to destroy for trial
enable_https = false # Need valid cert for true

# EKS Configuration (Ultra-cheap nodes)
kubernetes_version = "1.29"

# System Node Group (On-Demand, Minimum viable size)
system_node_group_desired_size     = 1
system_node_group_min_size         = 1
system_node_group_max_size         = 2
system_node_group_instance_types   = ["t4g.small"] # ARM, very cheap

# App Node Group (Spot for cost optimization)
app_spot_node_group_desired_size   = 1
app_spot_node_group_min_size       = 1
app_spot_node_group_max_size       = 2
app_spot_node_group_instance_types = ["t4g.small"] # ARM, very cheap

# MongoDB Atlas (Free Tier)
mongodb_version           = "7.0"
mongodb_major_version     = "7.0"
mongodb_instance_size     = "M0" # Free tier
mongodb_region            = "us-east-1"
mongodb_disk_size_gb      = 0 # Unused for M0
mongodb_database          = "ticket_booking_prod"
mongodb_enable_private_endpoint = false # Private Endpoint not supported for M0
mongodb_enable_outage_test = false
enable_cloudwatch_logs    = false
log_retention_days        = 1

# RabbitMQ (Free Tier Eligible)
rabbitmq_version   = "3.12.13"
mq_instance_type   = "mq.t3.micro" # Free tier eligible
mq_deployment_mode = "SINGLE_INSTANCE" # Cheaper than ACTIVE_STANDBY
mq_max_connections = 500
queue_depth_threshold = 50

# CloudFront
cloudfront_cache_default_ttl = 3600
enable_api_cache_behavior    = false
invalidate_on_apply          = false

# ECR
enable_image_scanning = false # Save costs

# Monitoring
alert_email = "ops-prod@example.com"

# Additional Tags
tags = {
  Environment = "prod"
  CostCenter  = "trial"
  ManagedBy   = "Terraform"
}
