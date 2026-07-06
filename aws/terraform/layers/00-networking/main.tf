# Layer 0: Networking
# This layer sets up the foundational networking infrastructure
# - VPC with public and private subnets
# - NAT Gateways for private subnet outbound access
# - Security groups
# L7 ingress is handled by Kubernetes AWS Load Balancer Controller

module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  region             = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnets))
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets

  tags = local.common_tags
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Networking"
    }
  )
}
