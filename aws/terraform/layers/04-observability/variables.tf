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

variable "log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 365
}

variable "alert_email" {
  description = "Alert email address"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
