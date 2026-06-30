variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "TicketBooking"
}

variable "terraform_state_bucket" {
  description = "S3 bucket that stores Terraform remote state."
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region of the Terraform remote state S3 bucket."
  type        = string
  default     = "us-east-1"
}

# MongoDB Atlas
variable "mongodb_public_key" {
  description = "MongoDB public key"
  type        = string
  sensitive   = true
}

variable "mongodb_private_key" {
  description = "MongoDB private key"
  type        = string
  sensitive   = true
}

variable "mongodb_org_id" {
  description = "MongoDB organization ID"
  type        = string
  sensitive   = true
}

variable "mongodb_version" {
  description = "MongoDB version"
  type        = string
  default     = "7.0"
}

variable "mongodb_major_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
}

variable "mongodb_instance_size" {
  description = "MongoDB instance size"
  type        = string
  default     = "M10"
}

variable "mongodb_region" {
  description = "MongoDB region"
  type        = string
  default     = "us-east-1"
}

variable "mongodb_disk_size_gb" {
  description = "MongoDB disk size"
  type        = number
  default     = 10
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
  sensitive   = true
}

variable "mongodb_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "mongodb_enable_private_endpoint" {
  description = "Enable MongoDB private endpoint"
  type        = bool
  default     = false
}

variable "mongodb_enable_outage_test" {
  description = "Enable MongoDB outage test"
  type        = bool
  default     = false
}

# Amazon MQ
variable "rabbitmq_version" {
  description = "RabbitMQ version"
  type        = string
  default     = "3.12.13"
}

variable "mq_instance_type" {
  description = "MQ instance type"
  type        = string
  default     = "mq.t3.micro"
}

variable "mq_deployment_mode" {
  description = "MQ deployment mode"
  type        = string
  default     = "ACTIVE_STANDBY_MULTI_AZ"
}

variable "mq_admin_username" {
  description = "MQ admin username"
  type        = string
  sensitive   = true
}

variable "mq_admin_password" {
  description = "MQ admin password"
  type        = string
  sensitive   = true
}

variable "mq_max_connections" {
  description = "MQ max connections"
  type        = number
  default     = 2048
}

variable "mq_channel_max" {
  description = "MQ channel max"
  type        = number
  default     = 2048
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 7
}

variable "queue_depth_threshold" {
  description = "Queue depth threshold"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
