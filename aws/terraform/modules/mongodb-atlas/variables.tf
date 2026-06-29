variable "environment" {
  description = "Environment name"
  type        = string
}

variable "mongodb_org_id" {
  description = "MongoDB Organization ID"
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

variable "instance_size_name" {
  description = "MongoDB Atlas instance size"
  type        = string
  default     = "M10"
}

variable "mongodb_region" {
  description = "MongoDB Atlas region"
  type        = string
  default     = "us-east-1"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "vpc_cidr" {
  description = "VPC CIDR block for whitelist"
  type        = string
}

variable "database_username" {
  description = "MongoDB database username"
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "MongoDB database password"
  type        = string
  sensitive   = true
}

variable "enable_private_endpoint" {
  description = "Enable MongoDB private endpoint"
  type        = bool
  default     = false
}

variable "enable_outage_test" {
  description = "Enable outage simulation testing"
  type        = bool
  default     = false
}

# Cloud Provider
variable "cloud_provider" {
  description = "Cloud provider for MongoDB Atlas cluster"
  type        = string
  default     = "AWS"
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable backup"
  type        = bool
  default     = true
}

variable "backup_type" {
  description = "Backup type (CONTINUOUS, SCHEDULED)"
  type        = string
  default     = "CONTINUOUS"
}

variable "pit_enabled" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

# Performance
variable "auto_scaling_disk_gb" {
  description = "Enable auto scaling disk GB"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable performance insights"
  type        = bool
  default     = true
}

# Application
variable "application_name" {
  description = "Application name for tagging"
  type        = string
  default     = "ticket-booking"
}

# Database User Configuration
variable "auth_database_name" {
  description = "Authentication database name"
  type        = string
  default     = "admin"
}

variable "database_role" {
  description = "Database role for the application user"
  type        = string
  default     = "readWriteAnyDatabase"
}

variable "scope_type" {
  description = "Scope type for database user"
  type        = string
  default     = "CLUSTER"
}

# IP Whitelist
variable "ip_whitelist_comment" {
  description = "Comment for IP whitelist entry"
  type        = string
  default     = "AWS VPC CIDR"
}

# Project Feature Flags
variable "enable_database_stats" {
  description = "Enable database specific stats collection"
  type        = bool
  default     = true
}

variable "enable_data_explorer" {
  description = "Enable data explorer"
  type        = bool
  default     = true
}

variable "enable_extended_storage" {
  description = "Enable extended storage sizes"
  type        = bool
  default     = true
}

variable "enable_performance_advisor" {
  description = "Enable performance advisor"
  type        = bool
  default     = true
}

variable "enable_realtime_performance" {
  description = "Enable realtime performance panel"
  type        = bool
  default     = true
}

variable "enable_schema_advisor" {
  description = "Enable schema advisor"
  type        = bool
  default     = true
}
