# Layer 0: Networking
# This layer sets up the foundational networking infrastructure
# - VPC with public and private subnets
# - NAT Gateways for private subnet outbound access
# - Application Load Balancer
# - Security groups

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  region             = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets

  tags = local.common_tags
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name_prefix                      = var.alb_name_prefix
  internal                         = var.alb_internal
  load_balancer_type               = var.alb_type
  security_groups                  = [module.vpc.alb_security_group_id]
  subnets                          = module.vpc.public_subnets
  enable_deletion_protection       = var.alb_enable_deletion_protection
  enable_http2                     = var.alb_enable_http2
  enable_cross_zone_load_balancing = var.alb_enable_cross_zone

  tags = merge(local.common_tags, {
    Name = "${var.environment}-alb"
  })
}

# ALB Target Group for API Gateway
resource "aws_lb_target_group" "api_gateway" {
  name_prefix = var.tg_name_prefix
  port        = var.tg_port
  protocol    = var.tg_protocol
  vpc_id      = module.vpc.vpc_id
  target_type = var.tg_target_type

  health_check {
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  stickiness {
    type            = var.stickiness_type
    enabled         = var.stickiness_enabled
    cookie_duration = var.stickiness_cookie_duration
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-api-gateway-tg"
  })

  depends_on = [aws_lb.main]
}

# ALB Listener for HTTP (redirect to HTTPS when enabled)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.http_listener_port
  protocol          = var.http_listener_protocol

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = var.https_listener_port
        protocol    = var.https_listener_protocol
        status_code = var.redirect_status_code
      }
    }

    target_group_arn = var.enable_https ? null : aws_lb_target_group.api_gateway.arn
  }
}

# ALB Listener for HTTPS (requires certificate)
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = var.https_listener_port
  protocol          = var.https_listener_protocol
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

# Outputs stored for downstream layers
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
