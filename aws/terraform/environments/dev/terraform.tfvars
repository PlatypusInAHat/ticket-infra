# Development Environment Configuration (Trial/Cost-Optimized)
# File: infra/aws/terraform/environments/dev/terraform.tfvars

environment  = "dev"
aws_region   = "us-east-1"
project_name = "TicketBooking"

# VPC Configuration (2 AZs are required by the ALB; one shared NAT Gateway to save ~$33/month)
vpc_cidr           = "10.0.0.0/16"
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
single_nat_gateway = true

# EKS Configuration
kubernetes_version = "1.29"

# System Node Group (On-Demand). Untainted so it also runs monitoring, Argo CD
# and app pods instead of sitting idle; t4g.small (2 GiB) is too small for that.
system_node_group_desired_size   = 1
system_node_group_min_size       = 1
system_node_group_max_size       = 2
system_node_group_instance_types = ["t4g.medium"] # ARM, 2 vCPU / 4 GiB
system_node_taint_enabled        = false

# App Node Group (Spot). Several ARM types with 4 GiB to lower interruption risk;
# max 4 nodes so HPA has room to scale during load tests.
app_spot_node_group_desired_size   = 1
app_spot_node_group_min_size       = 1
app_spot_node_group_max_size       = 4
app_spot_node_group_instance_types = ["t4g.medium", "m6g.medium", "m7g.medium"]

# Critical App Node Group (On-Demand). Deployments pinned to workload=critical
# need at least one node; the module default (2x m7g) is sized for prod.
app_on_demand_node_group_desired_size   = 1
app_on_demand_node_group_min_size       = 1
app_on_demand_node_group_max_size       = 2
app_on_demand_node_group_instance_types = ["t4g.medium"]

# MongoDB Atlas (Free Tier)
mongodb_version        = "7.0"
mongodb_major_version  = "7.0"
mongodb_instance_size  = "M0" # Free tier
mongodb_region         = "us-east-1"
mongodb_disk_size_gb   = 0 # Unused for M0
mongodb_database       = "ticket_booking"
enable_cloudwatch_logs = false
log_retention_days     = 1

# RabbitMQ (Free Tier Eligible)
rabbitmq_version   = "3.12.13"
mq_instance_type   = "mq.t3.micro"     # Free tier eligible
mq_deployment_mode = "SINGLE_INSTANCE" # Cheaper than ACTIVE_STANDBY

# Managed Redis is disabled by default for the student/demo budget.
# Enable only after setting a secret auth token and accepting ElastiCache cost.
enable_redis = false

# CloudFront
cloudfront_cache_default_ttl = 3600

# Monitoring
alert_email = "your-email@example.com"

# Additional Tags
tags = {
  Environment = "dev"
  CostCenter  = "trial"
  ManagedBy   = "Terraform"
}
