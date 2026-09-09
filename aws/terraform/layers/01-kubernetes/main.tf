# Layer 1: Kubernetes
# This layer sets up the EKS cluster with:
# - EKS cluster with control plane logging
# - System on-demand node group
# - App spot node group for cost optimization
# - OIDC provider for IRSA (IAM Roles for Service Accounts)
# - Cluster autoscaler IAM role

# Data source for networking layer outputs
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = "${var.environment}/00-networking/terraform.tfstate"
    region = var.terraform_state_region
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name              = "${var.environment}-eks"
  kubernetes_version        = var.kubernetes_version
  region                    = var.aws_region
  private_subnets           = data.terraform_remote_state.networking.outputs.private_subnets
  public_subnets            = data.terraform_remote_state.networking.outputs.public_subnets
  cluster_security_group_id = data.terraform_remote_state.networking.outputs.eks_cluster_security_group_id
  node_security_group_id    = data.terraform_remote_state.networking.outputs.eks_nodes_security_group_id
  manage_vpc_cni_addon      = var.manage_vpc_cni_addon
  manage_ebs_csi_addon      = var.manage_ebs_csi_addon

  vpc_cni_enable_network_policy    = var.vpc_cni_enable_network_policy
  vpc_cni_enable_policy_event_logs = var.vpc_cni_enable_policy_event_logs

  # Node group settings
  system_node_group_desired_size   = var.system_node_group_desired_size
  system_node_group_min_size       = var.system_node_group_min_size
  system_node_group_max_size       = var.system_node_group_max_size
  system_node_group_instance_types = var.system_node_group_instance_types

  app_spot_node_group_desired_size   = var.app_spot_node_group_desired_size
  app_spot_node_group_min_size       = var.app_spot_node_group_min_size
  app_spot_node_group_max_size       = var.app_spot_node_group_max_size
  app_spot_node_group_instance_types = var.app_spot_node_group_instance_types

  app_on_demand_node_group_desired_size   = var.app_on_demand_node_group_desired_size
  app_on_demand_node_group_min_size       = var.app_on_demand_node_group_min_size
  app_on_demand_node_group_max_size       = var.app_on_demand_node_group_max_size
  app_on_demand_node_group_instance_types = var.app_on_demand_node_group_instance_types

  tags = local.common_tags
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.14.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_id
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.networking.outputs.vpc_id
  }

  set {
    name  = "replicaCount"
    value = "2"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.load_balancer_controller_iam_role_arn
  }

  set {
    name  = "nodeSelector.workload"
    value = "system-pods"
  }

  set {
    name  = "tolerations[0].key"
    value = "system"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [module.eks]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  }

  set {
    name  = "nodeSelector.workload"
    value = "system-pods"
  }

  set {
    name  = "tolerations[0].key"
    value = "system"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [module.eks]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_id
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.cluster_autoscaler_iam_role_arn
  }

  set {
    name  = "extraArgs.expander"
    value = "least-waste"
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "nodeSelector.workload"
    value = "system-pods"
  }

  set {
    name  = "tolerations[0].key"
    value = "system"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "true"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  depends_on = [module.eks]
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Kubernetes"
    }
  )
}
