variable "cluster_name" {
  description = "Name of EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to use"
  type        = string
  default     = "1.29"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  type        = string
  default     = ""
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the cluster endpoint"
  type        = list(string)
  default     = []
}

variable "cluster_log_types" {
  description = "List of log types to enable for cluster logging"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the EKS secret encryption KMS key"
  type        = number
  default     = 7
}

variable "oidc_client_id" {
  description = "Client ID for OIDC provider"
  type        = string
  default     = "sts.amazonaws.com"
}

# Node Policy ARNs - Dynamic for_each
variable "node_policy_arns" {
  description = "Map of IAM policy names to attach to the node role"
  type        = map(string)
  default = {
    worker_node   = "AmazonEKSWorkerNodePolicy"
    cni           = "AmazonEKS_CNI_Policy"
    container_reg = "AmazonEC2ContainerRegistryReadOnly"
    ssm           = "AmazonSSMManagedInstanceCore"
  }
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
  description = "Desired number of nodes in system node group"
  type        = number
  default     = 1
}

variable "system_node_group_min_size" {
  description = "Minimum number of nodes in system node group"
  type        = number
  default     = 1
}

variable "system_node_group_max_size" {
  description = "Maximum number of nodes in system node group"
  type        = number
  default     = 3
}

variable "system_node_group_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large"]
}

# App Spot Node Group
variable "app_spot_node_group_desired_size" {
  description = "Desired number of nodes in app spot node group"
  type        = number
  default     = 2
}

variable "app_spot_node_group_min_size" {
  description = "Minimum number of nodes in app spot node group"
  type        = number
  default     = 2
}

variable "app_spot_node_group_max_size" {
  description = "Maximum number of nodes in app spot node group"
  type        = number
  default     = 10
}

variable "app_spot_node_group_instance_types" {
  description = "Instance types for app spot node group"
  type        = list(string)
  default     = ["t4g.medium", "t4g.large", "m7g.medium", "m7g.large"]
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# IAM and Policy Constants
variable "iam_policy_version" {
  description = "IAM policy version"
  type        = string
  default     = "2012-10-17"
}

variable "sts_assume_role_action" {
  description = "STS AssumeRole action"
  type        = string
  default     = "sts:AssumeRole"
}

variable "eks_service_principal" {
  description = "EKS service principal"
  type        = string
  default     = "eks.amazonaws.com"
}

variable "ec2_service_principal" {
  description = "EC2 service principal"
  type        = string
  default     = "ec2.amazonaws.com"
}

# Node Labels
variable "system_node_type_label_value" {
  description = "Label value for system node type"
  type        = string
  default     = "system"
}

variable "system_workload_label_value" {
  description = "Label value for system workload"
  type        = string
  default     = "system-pods"
}

variable "system_node_labels" {
  description = "Additional labels for system nodes"
  type        = map(string)
  default     = {}
}

variable "app_node_type_label_value" {
  description = "Label value for app node type"
  type        = string
  default     = "app"
}

variable "app_workload_label_value" {
  description = "Label value for app workload"
  type        = string
  default     = "general"
}

variable "spot_capacity_label_value" {
  description = "Label value for spot capacity"
  type        = string
  default     = "spot"
}

variable "app_spot_node_labels" {
  description = "Additional labels for app spot nodes"
  type        = map(string)
  default     = {}
}

# Node Taints
variable "system_taint_key" {
  description = "Taint key for system nodes"
  type        = string
  default     = "system"
}

variable "system_taint_value" {
  description = "Taint value for system nodes"
  type        = string
  default     = "true"
}

variable "system_taint_effect" {
  description = "Taint effect for system nodes"
  type        = string
  default     = "NoSchedule"
}

# Node Capacity Type
variable "app_spot_capacity_type" {
  description = "Capacity type for app spot nodes"
  type        = string
  default     = "SPOT"
}

# Karpenter Settings
variable "karpenter_evict_enabled" {
  description = "Enable Karpenter eviction"
  type        = bool
  default     = false
}

# Cluster Autoscaler
variable "cluster_autoscaler_namespace" {
  description = "Namespace for cluster autoscaler service account"
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  description = "Service account name for cluster autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "https_prefix_to_replace" {
  description = "HTTPS prefix to replace in OIDC URL"
  type        = string
  default     = "https://"
}

variable "https_prefix_replacement" {
  description = "Replacement string for HTTPS prefix"
  type        = string
  default     = ""
}

variable "resource_tag_value" {
  description = "Resource tag value for cluster autoscaler"
  type        = string
  default     = "owned"
}

variable "cluster_autoscaler_read_actions" {
  description = "Read actions for cluster autoscaler"
  type        = list(string)
  default = [
    "autoscaling:DescribeAutoScalingGroups",
    "autoscaling:DescribeAutoScalingInstances",
    "autoscaling:DescribeLaunchConfigurations",
    "autoscaling:DescribeScalingActivities",
    "autoscaling:DescribeTags",
    "ec2:DescribeInstanceTypes",
    "ec2:DescribeLaunchTemplateVersions"
  ]
}

variable "cluster_autoscaler_write_actions" {
  description = "Write actions for cluster autoscaler"
  type        = list(string)
  default = [
    "autoscaling:SetDesiredCapacity",
    "autoscaling:TerminateInstanceInAutoScalingGroup"
  ]
}

variable "cluster_autoscaler_resource" {
  description = "Resource for cluster autoscaler policy"
  type        = list(string)
  default     = ["*"]
}
