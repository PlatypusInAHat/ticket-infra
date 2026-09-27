variable "enable_redis" {
  description = "Create the managed Redis cluster"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used for Redis egress"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the Redis subnet group"
  type        = list(string)
}

variable "eks_nodes_security_group_id" {
  description = "EKS node security group allowed to connect to Redis"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
  default     = "redis7"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "num_cache_clusters" {
  description = "Number of cache nodes; use 1 for cost-optimized dev"
  type        = number
  default     = 1
  validation {
    condition     = var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6
    error_message = "num_cache_clusters must be between 1 and 6."
  }
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ for Redis replicas"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Optional Redis AUTH token; keep it in a secret tfvars input"
  type        = string
  sensitive   = true
  default     = ""
  validation {
    condition     = var.auth_token == "" || (length(var.auth_token) >= 16 && length(var.auth_token) <= 128)
    error_message = "auth_token must be empty or between 16 and 128 characters."
  }
}

variable "apply_immediately" {
  description = "Apply Redis changes immediately"
  type        = bool
  default     = false
}

variable "snapshot_retention_limit" {
  description = "Number of daily Redis snapshots to retain"
  type        = number
  default     = 1
}

variable "maintenance_window" {
  description = "Weekly Redis maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
