# VPC Module - Networking Foundation
# Creates VPC, subnets, NAT gateways, route tables, and security groups

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  for_each                = toset(keys({ for idx, az in var.availability_zones : idx => az }))
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[tonumber(each.key)]
  availability_zone       = var.availability_zones[tonumber(each.key)]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name                     = "${var.environment}-public-subnet-${tonumber(each.key) + 1}"
    "kubernetes.io/role/elb" = "1"
    "karpenter.sh/discovery" = var.environment
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each          = toset(keys({ for idx, az in var.availability_zones : idx => az }))
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[tonumber(each.key)]
  availability_zone = var.availability_zones[tonumber(each.key)]

  tags = merge(var.tags, {
    Name                              = "${var.environment}-private-subnet-${tonumber(each.key) + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.environment
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = toset(keys({ for idx, az in var.availability_zones : idx => az }))
  domain   = var.eip_domain

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.environment}-eip-${tonumber(each.key) + 1}"
  })
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  for_each      = toset(keys({ for idx, az in var.availability_zones : idx => az }))
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-${tonumber(each.key) + 1}"
  })
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-public-rt"
  })
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ for high availability)
resource "aws_route_table" "private" {
  for_each = toset(keys({ for idx, az in var.availability_zones : idx => az }))
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = var.default_route_cidr
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-private-rt-${tonumber(each.key) + 1}"
  })
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = var.alb_sg_description
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.alb_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = var.egress_from_port
    to_port     = var.egress_to_port
    protocol    = var.egress_protocol
    cidr_blocks = [var.default_route_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-alb-sg"
  })
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.environment}-eks-cluster-sg"
  description = var.eks_cluster_sg_description
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.eks_cluster_ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      security_groups = ingress.value.security_groups
      description     = ingress.value.description
    }
  }

  egress {
    from_port   = var.egress_from_port
    to_port     = var.egress_to_port
    protocol    = var.egress_protocol
    cidr_blocks = [var.default_route_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-eks-cluster-sg"
  })
}

# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.environment}-eks-nodes-sg"
  description = var.eks_nodes_sg_description
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.eks_nodes_ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      security_groups = lookup(ingress.value, "security_groups", [])
      self            = lookup(ingress.value, "self", false)
      description     = ingress.value.description
    }
  }

  egress {
    from_port   = var.egress_from_port
    to_port     = var.egress_to_port
    protocol    = var.egress_protocol
    cidr_blocks = [var.default_route_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-eks-nodes-sg"
  })
}
