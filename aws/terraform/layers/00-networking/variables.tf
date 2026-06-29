variable "environment" {
  description = "Environment name (dev, staging, prod)"
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

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "enable_https" {
  description = "Enable HTTPS on ALB"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for ALB"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ALB Configuration
variable "alb_name_prefix" {
  description = "ALB name prefix"
  type        = string
  default     = "alb"
}

variable "alb_internal" {
  description = "Whether ALB is internal"
  type        = bool
  default     = false
}

variable "alb_type" {
  description = "Load balancer type"
  type        = string
  default     = "application"
}

variable "alb_enable_http2" {
  description = "Enable HTTP/2 on ALB"
  type        = bool
  default     = true
}

variable "alb_enable_cross_zone" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

# Target Group Configuration
variable "tg_name_prefix" {
  description = "Target group name prefix"
  type        = string
  default     = "api"
}

variable "tg_port" {
  description = "Target group port"
  type        = number
  default     = 80
}

variable "tg_protocol" {
  description = "Target group protocol"
  type        = string
  default     = "HTTP"
}

variable "tg_target_type" {
  description = "Target group target type"
  type        = string
  default     = "ip"
}

# Health Check Configuration
variable "health_check_healthy_threshold" {
  description = "Healthy threshold for health check"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Unhealthy threshold for health check"
  type        = number
  default     = 2
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 3
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "Health check success HTTP status codes"
  type        = string
  default     = "200"
}

# Stickiness Configuration
variable "stickiness_type" {
  description = "Stickiness type"
  type        = string
  default     = "lb_cookie"
}

variable "stickiness_enabled" {
  description = "Enable stickiness"
  type        = bool
  default     = true
}

variable "stickiness_cookie_duration" {
  description = "Stickiness cookie duration in seconds"
  type        = number
  default     = 86400
}

# Listener Configuration
variable "http_listener_port" {
  description = "HTTP listener port"
  type        = string
  default     = "80"
}

variable "http_listener_protocol" {
  description = "HTTP listener protocol"
  type        = string
  default     = "HTTP"
}

variable "https_listener_port" {
  description = "HTTPS listener port"
  type        = string
  default     = "443"
}

variable "https_listener_protocol" {
  description = "HTTPS listener protocol"
  type        = string
  default     = "HTTPS"
}

variable "redirect_status_code" {
  description = "HTTP redirect status code"
  type        = string
  default     = "HTTP_301"
}
