variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_image_scanning" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "eks_node_role_arn" {
  description = "EKS node role ARN for ECR pull permissions"
  type        = string
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# Repository Configuration
variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default = [
    "api-gateway",
    "auth-service",
    "catalog-service",
    "booking-service",
    "checkin-service",
    "notification-service",
    "frontend"
  ]
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting"
  type        = string
  default     = "IMMUTABLE"
}

variable "encryption_type" {
  description = "ECR encryption type"
  type        = string
  default     = "KMS"
}

variable "kms_key_arn" {
  description = "Optional existing KMS key ARN for ECR repository encryption. A customer managed key is created when empty."
  type        = string
  default     = ""
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the generated ECR KMS key"
  type        = number
  default     = 7
}

# Lifecycle Rules - Single consolidated variable
variable "lifecycle_rules" {
  description = "List of ECR lifecycle rules"
  type = list(object({
    description  = string
    tag_status   = string
    tag_prefixes = optional(list(string))
    count_type   = string
    count_unit   = optional(string)
    count_number = number
    action_type  = string
  }))
  default = [
    {
      description  = "Keep last 30 release and CI images"
      tag_status   = "tagged"
      tag_prefixes = ["v", "release", "dev-", "staging-", "main-", "prod-", "sha-"]
      count_type   = "imageCountMoreThan"
      count_number = 30
      action_type  = "expire"
    },
    {
      description  = "Delete untagged images older than 30 days"
      tag_status   = "untagged"
      count_type   = "sinceImagePushed"
      count_unit   = "days"
      count_number = 30
      action_type  = "expire"
    }
  ]
}

# IAM Policy Configuration
variable "iam_policy_version" {
  description = "IAM policy version"
  type        = string
  default     = "2012-10-17"
}

variable "policy_statement_sid" {
  description = "SID for ECR policy statement"
  type        = string
  default     = "AllowEKSNodesToPull"
}

variable "ecr_pull_actions" {
  description = "ECR actions allowed for pull"
  type        = list(string)
  default = [
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "ecr:GetAuthorizationToken"
  ]
}
