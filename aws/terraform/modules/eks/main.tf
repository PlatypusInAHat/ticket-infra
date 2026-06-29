# EKS Module - Kubernetes Cluster Setup
# Creates EKS cluster, node groups (on-demand and spot), IAM roles, and OIDC provider

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Get caller identity for tags
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "${var.cluster_name}-cluster-"

  assume_role_policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Action = var.sts_assume_role_action
        Effect = "Allow"
        Principal = {
          Service = var.eks_service_principal
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnets, var.public_subnets)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [var.cluster_security_group_id]
  }

  enabled_cluster_log_types = var.cluster_log_types

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = var.tags
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "cluster_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = [var.oidc_client_id]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  name_prefix = "${var.cluster_name}-node-"

  assume_role_policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Action = var.sts_assume_role_action
        Effect = "Allow"
        Principal = {
          Service = var.ec2_service_principal
        }
      }
    ]
  })

  tags = var.tags
}

# Node IAM Policy Attachments - Dynamic using for_each
resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each   = var.node_policy_arns
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
  role       = aws_iam_role.eks_node_role.name
}

# System On-Demand Node Group
resource "aws_eks_node_group" "system_on_demand" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-system-on-demand"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnets

  scaling_config {
    desired_size = var.system_node_group_desired_size
    max_size     = var.system_node_group_max_size
    min_size     = var.system_node_group_min_size
  }

  instance_types = var.system_node_group_instance_types

  labels = merge(
    var.system_node_labels,
    {
      "node-type" = var.system_node_type_label_value
      "workload"  = var.system_workload_label_value
    }
  )

  taints {
    key    = var.system_taint_key
    value  = var.system_taint_value
    effect = var.system_taint_effect
  }

  tags = merge(var.tags, {
    "karpenter.sh/do-not-evict" = tostring(var.karpenter_evict_enabled)
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies,
  ]
}

# Application Spot Node Group
resource "aws_eks_node_group" "app_spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-app-spot"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnets
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.app_spot_node_group_desired_size
    max_size     = var.app_spot_node_group_max_size
    min_size     = var.app_spot_node_group_min_size
  }

  capacity_type = var.app_spot_capacity_type

  instance_types = var.app_spot_node_group_instance_types

  labels = merge(
    var.app_spot_node_labels,
    {
      "node-type" = var.app_node_type_label_value
      "workload"  = var.app_workload_label_value
      "capacity"  = var.spot_capacity_label_value
    }
  )

  tags = merge(var.tags, {
    "karpenter.sh/do-not-evict" = tostring(var.karpenter_evict_enabled)
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Cluster Autoscaler IAM Role
resource "aws_iam_role" "cluster_autoscaler" {
  name_prefix = "${var.cluster_name}-autoscaler-"

  assume_role_policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Action = var.sts_assume_role_action
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, var.https_prefix_to_replace, var.https_prefix_replacement)}:sub" = "system:serviceaccount:${var.cluster_autoscaler_namespace}:${var.cluster_autoscaler_service_account}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name_prefix = "autoscaler-"
  role        = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Effect   = "Allow"
        Action   = var.cluster_autoscaler_read_actions
        Resource = var.cluster_autoscaler_resource
      },
      {
        Effect   = "Allow"
        Action   = var.cluster_autoscaler_write_actions
        Resource = var.cluster_autoscaler_resource
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = var.resource_tag_value
          }
        }
      }
    ]
  })
}
