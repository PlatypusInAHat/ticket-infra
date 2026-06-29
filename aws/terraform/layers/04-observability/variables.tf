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

variable "log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 7
}

variable "alert_email" {
  description = "Alert email address"
  type        = string
  default     = ""
}

variable "eks_cpu_threshold" {
  description = "EKS CPU threshold"
  type        = number
  default     = 80
}

variable "eks_memory_threshold" {
  description = "EKS memory threshold"
  type        = number
  default     = 85
}

variable "alb_response_time_threshold" {
  description = "ALB response time threshold"
  type        = number
  default     = 1
}

variable "error_rate_threshold" {
  description = "Error rate threshold"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
