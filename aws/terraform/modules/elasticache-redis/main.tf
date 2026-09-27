terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

resource "aws_elasticache_subnet_group" "redis" {
  count      = var.enable_redis ? 1 : 0
  name       = "${var.environment}-ticketstage-redis"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "redis" {
  count       = var.enable_redis ? 1 : 0
  name_prefix = "${var.environment}-redis-"
  description = "Allow Redis only from EKS worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.eks_nodes_security_group_id]
    description     = "Redis from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis VPC egress"
  }

  tags = var.tags
}

resource "aws_elasticache_parameter_group" "redis" {
  count  = var.enable_redis ? 1 : 0
  name   = "${var.environment}-ticketstage-redis7"
  family = var.parameter_group_family
  tags   = var.tags
}

resource "aws_elasticache_replication_group" "redis" {
  count                      = var.enable_redis ? 1 : 0
  replication_group_id       = "${var.environment}-ticketstage-redis"
  description                = "Shared Redis for TicketStage rate limiting"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  port                       = var.port
  parameter_group_name       = aws_elasticache_parameter_group.redis[0].name
  subnet_group_name          = aws_elasticache_subnet_group.redis[0].name
  security_group_ids         = [aws_security_group.redis[0].id]
  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.multi_az_enabled && var.num_cache_clusters > 1
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token != "" ? var.auth_token : null
  apply_immediately          = var.apply_immediately
  snapshot_retention_limit   = var.snapshot_retention_limit
  maintenance_window         = var.maintenance_window
  tags                       = var.tags

  lifecycle {
    precondition {
      condition     = !var.enable_redis || var.auth_token != ""
      error_message = "redis_auth_token is required when managed Redis is enabled."
    }
  }
}
