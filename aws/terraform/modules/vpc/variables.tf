variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "Map public IP on launch for public subnets"
  type        = bool
  default     = false
}

variable "eip_domain" {
  description = "Domain for Elastic IP"
  type        = string
  default     = "vpc"
}

variable "default_route_cidr" {
  description = "Default route CIDR block (0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "egress_from_port" {
  description = "Egress from port"
  type        = number
  default     = 0
}

variable "egress_to_port" {
  description = "Egress to port"
  type        = number
  default     = 0
}

variable "egress_protocol" {
  description = "Egress protocol (-1 for all)"
  type        = string
  default     = "-1"
}

variable "eks_cluster_sg_description" {
  description = "Description for EKS cluster security group"
  type        = string
  default     = "Security group for EKS cluster"
}

variable "eks_cluster_ingress_rules" {
  description = "Ingress rules for EKS cluster security group"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    security_groups = list(string)
    description     = string
  }))
  default = []
}

variable "eks_nodes_sg_description" {
  description = "Description for EKS nodes security group"
  type        = string
  default     = "Security group for EKS nodes"
}

variable "eks_nodes_ingress_rules" {
  description = "Ingress rules for EKS nodes security group"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    security_groups = optional(list(string))
    self            = optional(bool, false)
    description     = string
  }))
  default = [
    {
      from_port   = 1025
      to_port     = 65535
      protocol    = "tcp"
      description = "Allow pods to communicate with cluster API"
    },
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      self        = true
      description = "Allow node to node communication"
    }
  ]
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

variable "flow_log_group_name_prefix" {
  description = "CloudWatch log group prefix for VPC flow logs"
  type        = string
  default     = "/aws/vpc/flow-logs"
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention days for VPC flow logs"
  type        = number
  default     = 365
}

variable "flow_log_traffic_type" {
  description = "Traffic type captured by VPC flow logs"
  type        = string
  default     = "ALL"
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for generated VPC flow log KMS key"
  type        = number
  default     = 7
}

variable "iam_policy_version" {
  description = "IAM policy document version"
  type        = string
  default     = "2012-10-17"
}
