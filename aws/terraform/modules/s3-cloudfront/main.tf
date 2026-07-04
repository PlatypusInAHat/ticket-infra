# S3 and CloudFront Module
# Creates S3 bucket for static frontend hosting and CloudFront CDN distribution

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket for Frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.environment}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "frontend" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS key for ${var.environment} frontend bucket encryption"
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
          Service = "logs.us-east-1.amazonaws.com"
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${var.environment}-frontend-cloudfront*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "frontend" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${var.environment}-frontend-s3"
  target_key_id = aws_kms_key.frontend[0].key_id
}

locals {
  frontend_kms_key_arn   = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.frontend[0].arn
  cloudfront_web_acl_arn = var.cloudfront_web_acl_arn != "" ? var.cloudfront_web_acl_arn : aws_wafv2_web_acl.frontend[0].arn
}

#checkov:skip=CKV_AWS_145:AWS S3/CloudFront log delivery destinations use SSE-S3 for broad service compatibility; application buckets remain KMS encrypted.
resource "aws_s3_bucket" "frontend_logs" {
  bucket = "${var.environment}-frontend-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.environment}-frontend-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#checkov:skip=CKV2_AWS_65:Legacy S3 and CloudFront access log delivery still requires ACL-compatible ownership on the dedicated log bucket.
resource "aws_s3_bucket_ownership_controls" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id
  acl    = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.frontend_logs,
    aws_s3_bucket_public_access_block.frontend_logs
  ]
}

resource "aws_s3_bucket_versioning" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend_logs" {
  bucket = aws_s3_bucket.frontend_logs.id

  rule {
    id = "expire-access-logs"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }

    expiration {
      days = var.access_log_expiration_days
    }

    status = var.lifecycle_rule_status
  }
}

resource "aws_s3_bucket_logging" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  target_bucket = aws_s3_bucket.frontend_logs.id
  target_prefix = "s3-access/"
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = var.versioning_status
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.frontend_kms_key_arn
      sse_algorithm     = var.sse_algorithm
    }

    bucket_key_enabled = true
  }
}

# Lifecycle policy to reduce costs
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id = var.lifecycle_rule_id

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_transition_days
      storage_class   = var.noncurrent_transition_storage_class
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }

    status = var.lifecycle_rule_status
  }
}

# CORS configuration
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.allowed_origins
    max_age_seconds = var.cors_max_age_seconds
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "frontend" {
  comment = "OAI for ${var.environment} frontend"
}

resource "aws_wafv2_web_acl" "frontend" {
  count = var.cloudfront_web_acl_arn == "" ? 1 : 0

  name        = "${var.environment}-frontend-cloudfront"
  description = "Baseline WAF for ${var.environment} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-frontend-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-frontend-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-frontend"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.cloudfront_web_acl_arn == "" ? 1 : 0

  name              = "aws-waf-logs-${var.environment}-frontend-cloudfront"
  retention_in_days = var.waf_log_retention_days
  kms_key_id        = local.frontend_kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.environment}-frontend-waf-logs"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "frontend" {
  count = var.cloudfront_web_acl_arn == "" ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.frontend[0].arn
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.environment}-frontend-security-headers"
  comment = "Security headers for ${var.environment} frontend"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }

    xss_protection {
      mode_block = true
      override   = true
      protection = true
    }
  }
}

# S3 Bucket Policy - Allow CloudFront OAI
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Sid    = var.bucket_policy_sid
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend.iam_arn
        }
        Action   = var.bucket_policy_action
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

#checkov:skip=CKV2_AWS_47:The managed WebACL includes AWSManagedRulesKnownBadInputsRuleSet; Checkov cannot resolve the conditional local WebACL ARN here.
# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = var.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend.cloudfront_access_identity_path
    }
  }

  enabled             = var.cloudfront_enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  default_root_object = var.default_root_object
  http_version        = var.http_version
  aliases             = var.custom_domain != "" ? [var.custom_domain] : []
  web_acl_id          = local.cloudfront_web_acl_arn

  logging_config {
    bucket          = aws_s3_bucket.frontend_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront/"
  }

  # Cache behavior for static assets
  default_cache_behavior {
    allowed_methods            = var.default_allowed_methods
    cached_methods             = var.default_cached_methods
    target_origin_id           = var.s3_origin_id
    compress                   = var.enable_compression
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    viewer_protocol_policy     = var.viewer_protocol_policy

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.cache_min_ttl
    default_ttl = var.cache_default_ttl
    max_ttl     = var.cache_max_ttl
  }

  # Cache behavior for index.html (no caching)
  ordered_cache_behavior {
    path_pattern               = var.index_path_pattern
    allowed_methods            = var.default_allowed_methods
    cached_methods             = var.default_cached_methods
    target_origin_id           = var.s3_origin_id
    compress                   = var.enable_compression
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    viewer_protocol_policy     = var.viewer_protocol_policy

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Cache behavior for API calls (passthrough to ALB)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_api_cache_behavior ? [1] : []
    content {
      path_pattern               = var.api_path_pattern
      allowed_methods            = var.api_allowed_methods
      cached_methods             = var.default_cached_methods
      target_origin_id           = var.s3_origin_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
      viewer_protocol_policy     = var.api_viewer_protocol_policy

      forwarded_values {
        query_string = true

        cookies {
          forward = "all"
        }

        headers = ["*"]
      }

      min_ttl     = 0
      default_ttl = 0
      max_ttl     = 0
    }
  }

  # Custom error responses - Dynamic
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain == "" ? true : false
    acm_certificate_arn            = var.custom_domain != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.custom_domain != "" ? var.ssl_support_method : null
    minimum_protocol_version       = var.minimum_protocol_version
  }

  tags = var.tags
}

# CloudFront cache invalidation
resource "null_resource" "invalidate_cache" {
  count = var.invalidate_on_apply ? 1 : 0

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths '/*'"
  }

  depends_on = [aws_cloudfront_distribution.frontend]
}
