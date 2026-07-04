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

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment}-default-sg-restricted"
  })
}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key for ${var.environment} VPC flow logs"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Sid    = "EnableAccountRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUse"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.flow_log_group_name_prefix}/${var.environment}*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc-flow-logs-kms"
  })
}

resource "aws_kms_alias" "vpc_flow_logs" {
  name          = "alias/${var.environment}-vpc-flow-logs"
  target_key_id = aws_kms_key.vpc_flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "${var.flow_log_group_name_prefix}/${var.environment}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name_prefix = "${var.environment}-vpc-flow-logs-"

  assume_role_policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name_prefix = "vpc-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs.arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc-flow-log"
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
    cidr_blocks = [var.vpc_cidr]
    description = "Allow cluster control plane outbound traffic inside the VPC"
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
    cidr_blocks = [var.vpc_cidr]
    description = "Allow node outbound traffic inside the VPC"
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-eks-nodes-sg"
  })
}
