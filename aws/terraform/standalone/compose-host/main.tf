# Single-host trial environment
# One Graviton EC2 instance runs the app repo's docker-compose.yml (6 services,
# 5 MongoDB, RabbitMQ). Cloudflare Tunnel publishes the API gateway, so there is
# no ALB, no NAT Gateway, no inbound port and no SSH: access is via SSM.
# Secrets never appear in Terraform state or user data; the instance reads them
# from SSM Parameter Store at boot.

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals {
  name = "${var.environment}-compose-host"

  ssm_parameter_names = compact([
    var.app_env_parameter,
    var.tunnel_token_parameter,
    var.git_token_parameter,
  ])

  ssm_parameter_arns = [
    for name in local.ssm_parameter_names :
    "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(name, "/")}"
  ]
}

# IAM: SSM Session Manager + read only the parameters this host needs
resource "aws_iam_role" "host" {
  name_prefix = "${local.name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "read_parameters" {
  name_prefix = "read-parameters-"
  role        = aws_iam_role.host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.ssm_parameter_arns
      }
    ]
  })
}

resource "aws_iam_instance_profile" "host" {
  name_prefix = "${local.name}-"
  role        = aws_iam_role.host.name
}

# Security group: no inbound rules. Egress limited to what provisioning and the
# app need: HTTP/HTTPS (packages, images, GitHub, payment/Atlas APIs), SMTP
# submission (email), and Cloudflare Tunnel (7844 TCP/UDP).
resource "aws_security_group" "host" {
  name_prefix = "${local.name}-"
  description = "TicketStage compose host, egress only"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "HTTP for package repositories"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS for images, GitHub, AWS APIs and payment providers"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "SMTP submission for transactional email"
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Cloudflare Tunnel (http2)"
    from_port   = 7844
    to_port     = 7844
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Cloudflare Tunnel (quic)"
    from_port   = 7844
    to_port     = 7844
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "host" {
  #checkov:skip=CKV_AWS_88:Public IP is used only for egress (no inbound rules); it replaces a ~$33/month NAT Gateway.
  #checkov:skip=CKV_AWS_126:Detailed monitoring is not needed for a trial host.
  ami                         = data.aws_ssm_parameter.al2023_arm64.value
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.host.id]
  iam_instance_profile        = aws_iam_instance_profile.host.name
  associate_public_ip_address = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    region                 = var.aws_region
    app_repo_url           = var.app_repo_url
    app_repo_ref           = var.app_repo_ref
    app_env_parameter      = var.app_env_parameter
    tunnel_token_parameter = var.tunnel_token_parameter
    git_token_parameter    = var.git_token_parameter
    docker_compose_version = var.docker_compose_version
    cloudflared_version    = var.cloudflared_version
  })

  tags = {
    Name = local.name
  }

  # MongoDB and RabbitMQ data live on the root volume. Do not replace the host
  # just because a newer AMI was published or the bootstrap script changed;
  # recreate it deliberately with `terraform apply -replace=aws_instance.host`.
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  depends_on = [
    aws_iam_role_policy.read_parameters,
    aws_iam_role_policy_attachment.ssm_core,
  ]
}
