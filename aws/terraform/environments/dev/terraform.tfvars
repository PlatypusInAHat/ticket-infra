# Development Environment Configuration (Trial/Cost-Optimized)
# File: infra/aws/terraform/environments/dev/terraform.tfvars

environment = "dev"
aws_region  = "us-east-1"
project_name = "TicketBooking"

# VPC Configuration (Minimizing to 2 AZs for ALB requirement -> 2 NAT Gateways)
vpc_cidr        = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

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
mongodb_database          = "ticket_booking"
enable_cloudwatch_logs    = false
log_retention_days        = 1

# RabbitMQ (Free Tier Eligible)
rabbitmq_version  = "3.12.13"
mq_instance_type  = "mq.t3.micro" # Free tier eligible
mq_deployment_mode = "SINGLE_INSTANCE" # Cheaper than ACTIVE_STANDBY

# CloudFront
cloudfront_cache_default_ttl = 3600
enable_api_cache_behavior    = false

# Monitoring
alert_email = "your-email@example.com"

# Additional Tags
tags = {
  Environment = "dev"
  CostCenter  = "trial"
  ManagedBy   = "Terraform"
}
