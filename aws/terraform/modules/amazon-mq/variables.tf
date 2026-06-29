variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for MQ broker"
  type        = list(string)
}

variable "eks_nodes_security_group_id" {
  description = "EKS nodes security group ID"
  type        = string
}

variable "rabbitmq_version" {
  description = "RabbitMQ version"
  type        = string
  default     = "3.12.13"
}

variable "instance_type" {
  description = "MQ broker instance type"
  type        = string
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  description = "Deployment mode (SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ)"
  type        = string
  default     = "ACTIVE_STANDBY_MULTI_AZ"
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password"
  type        = string
  sensitive   = true
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
  description = "Queue depth alarm threshold"
  type        = number
  default     = 100
}

variable "max_connections" {
  description = "Max connections for RabbitMQ"
  type        = number
  default     = 2048
}

variable "channel_max" {
  description = "Max channels per connection"
  type        = number
  default     = 2048
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# Security Group Configuration
variable "sg_name_prefix" {
  description = "Security group name prefix"
  type        = string
  default     = "mq-"
}

variable "sg_description" {
  description = "Security group description"
  type        = string
  default     = "Security group for Amazon MQ"
}

variable "mq_ingress_rules" {
  description = "Ingress rules for MQ security group"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    security_groups = optional(list(string))
    cidr_blocks     = optional(list(string))
    description     = string
  }))
  default = []
}

variable "mq_egress_rules" {
  description = "Egress rules for MQ security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}

# Engine Configuration
variable "engine_type" {
  description = "MQ engine type"
  type        = string
  default     = "RabbitMQ"
}

variable "engine_type_lower" {
  description = "MQ engine type in lowercase for naming"
  type        = string
  default     = "rabbitmq"
}

variable "publicly_accessible" {
  description = "Whether broker is publicly accessible"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Enable auto minor version upgrade"
  type        = bool
  default     = true
}

# CloudWatch Log Group
variable "log_group_prefix" {
  description = "CloudWatch log group name prefix"
  type        = string
  default     = "/aws/mq"
}

# CloudWatch Alarm Configuration
variable "alarm_name_suffix" {
  description = "Suffix for alarm name"
  type        = string
  default     = "mq-queue-depth-high"
}

variable "alarm_comparison_operator" {
  description = "Comparison operator for alarm"
  type        = string
  default     = "GreaterThanThreshold"
}

variable "alarm_evaluation_periods" {
  description = "Number of evaluation periods"
  type        = string
  default     = "2"
}

variable "alarm_metric_name" {
  description = "Metric name for alarm"
  type        = string
  default     = "QueueDepth"
}

variable "alarm_namespace" {
  description = "Namespace for alarm metric"
  type        = string
  default     = "AWS/MQ"
}

variable "alarm_period" {
  description = "Period in seconds for alarm"
  type        = string
  default     = "300"
}

variable "alarm_statistic" {
  description = "Statistic for alarm"
  type        = string
  default     = "Average"
}

variable "alarm_description" {
  description = "Description for alarm"
  type        = string
  default     = "Alert when MQ queue depth is high"
}

variable "alarm_treat_missing_data" {
  description = "How to treat missing data in alarm"
  type        = string
  default     = "notBreaching"
}

# Broker Configuration
variable "broker_config_description" {
  description = "Description for broker configuration"
  type        = string
  default     = "RabbitMQ broker configuration"
}
