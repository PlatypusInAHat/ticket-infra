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
      sse_algorithm = var.sse_algorithm
    }
  }
}

# Lifecycle policy to reduce costs
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id = var.lifecycle_rule_id

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_transition_days
      storage_class   = var.noncurrent_transition_storage_class
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration_days
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

  # Cache behavior for static assets
  default_cache_behavior {
    allowed_methods        = var.default_allowed_methods
    cached_methods         = var.default_cached_methods
    target_origin_id       = var.s3_origin_id
    compress               = var.enable_compression
    viewer_protocol_policy = var.viewer_protocol_policy

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
    path_pattern           = var.index_path_pattern
    allowed_methods        = var.default_allowed_methods
    cached_methods         = var.default_cached_methods
    target_origin_id       = var.s3_origin_id
    compress               = var.enable_compression
    viewer_protocol_policy = var.viewer_protocol_policy

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
      path_pattern           = var.api_path_pattern
      allowed_methods        = var.api_allowed_methods
      cached_methods         = var.default_cached_methods
      target_origin_id       = var.s3_origin_id
      viewer_protocol_policy = var.api_viewer_protocol_policy

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

  dynamic "aliases" {
    for_each = var.custom_domain != "" ? [var.custom_domain] : []
    content {
      items = [aliases.value]
    }
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
