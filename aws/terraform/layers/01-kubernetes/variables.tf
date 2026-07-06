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

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "manage_vpc_cni_addon" {
  description = "Manage the Amazon VPC CNI EKS add-on from Terraform."
  type        = bool
  default     = true
}

variable "vpc_cni_enable_network_policy" {
  description = "Enable Kubernetes NetworkPolicy enforcement in the Amazon VPC CNI add-on."
  type        = bool
  default     = true
}

variable "vpc_cni_enable_policy_event_logs" {
  description = "Enable policy event logs for the VPC CNI network policy agent."
  type        = bool
  default     = true
}

# System Node Group
variable "system_node_group_desired_size" {
  description = "Desired size for system node group"
  type        = number
  default     = 1
}

variable "system_node_group_min_size" {
  description = "Min size for system node group"
  type        = number
  default     = 1
}

variable "system_node_group_max_size" {
  description = "Max size for system node group"
  type        = number
  default     = 3
}

variable "system_node_group_instance_types" {
  description = "Instance types for system nodes"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large"]
}

# App Spot Node Group
variable "app_spot_node_group_desired_size" {
  description = "Desired size for app spot node group"
  type        = number
  default     = 2
}

variable "app_spot_node_group_min_size" {
  description = "Min size for app spot node group"
  type        = number
  default     = 2
}

variable "app_spot_node_group_max_size" {
  description = "Max size for app spot node group"
  type        = number
  default     = 10
}

variable "app_spot_node_group_instance_types" {
  description = "Instance types for app spot nodes"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large", "m7g.medium", "m7g.large"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
