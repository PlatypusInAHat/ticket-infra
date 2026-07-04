variable "environment" {
  description = "Environment name"
  type        = string
}

variable "allowed_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "cache_min_ttl" {
  description = "CloudFront minimum cache TTL in seconds"
  type        = number
  default     = 0
}

variable "cache_default_ttl" {
  description = "CloudFront default cache TTL in seconds"
  type        = number
  default     = 86400
}

variable "cache_max_ttl" {
  description = "CloudFront maximum cache TTL in seconds"
  type        = number
  default     = 31536000
}

variable "enable_api_cache_behavior" {
  description = "Enable cache behavior for API calls"
  type        = bool
  default     = false
}

variable "custom_domain" {
  description = "Custom domain for CloudFront distribution"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = ""
}

variable "invalidate_on_apply" {
  description = "Invalidate CloudFront cache on apply"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# S3 Public Access Block
variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

# S3 Versioning
variable "versioning_status" {
  description = "S3 bucket versioning status"
  type        = string
  default     = "Enabled"
}

# S3 Encryption
variable "sse_algorithm" {
  description = "Server-side encryption algorithm"
  type        = string
  default     = "aws:kms"
}

variable "kms_key_arn" {
  description = "Optional existing KMS key ARN for frontend bucket encryption. A customer managed key is created when empty."
  type        = string
  default     = ""
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the generated frontend bucket KMS key"
  type        = number
  default     = 7
}

# S3 Lifecycle
variable "lifecycle_rule_id" {
  description = "Lifecycle rule ID"
  type        = string
  default     = "transition-old-versions"
}

variable "lifecycle_rule_status" {
  description = "Lifecycle rule status"
  type        = string
  default     = "Enabled"
}

variable "noncurrent_transition_days" {
  description = "Days before transitioning noncurrent versions"
  type        = number
  default     = 30
}

variable "noncurrent_transition_storage_class" {
  description = "Storage class for noncurrent version transition"
  type        = string
  default     = "STANDARD_IA"
}

variable "noncurrent_expiration_days" {
  description = "Days before expiring noncurrent versions"
  type        = number
  default     = 90
}

# CORS
variable "cors_allowed_headers" {
  description = "Allowed CORS headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "Allowed CORS methods"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cors_max_age_seconds" {
  description = "CORS max age in seconds"
  type        = number
  default     = 3600
}

# S3 Bucket Policy
variable "iam_policy_version" {
  description = "IAM policy version"
  type        = string
  default     = "2012-10-17"
}

variable "bucket_policy_sid" {
  description = "SID for S3 bucket policy statement"
  type        = string
  default     = "AllowCloudFrontOAI"
}

variable "bucket_policy_action" {
  description = "Action allowed in bucket policy"
  type        = string
  default     = "s3:GetObject"
}

# CloudFront Distribution
variable "s3_origin_id" {
  description = "Origin ID for S3 in CloudFront"
  type        = string
  default     = "s3-frontend"
}

variable "cloudfront_enabled" {
  description = "Enable CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_web_acl_arn" {
  description = "Optional existing WAFv2 WebACL ARN for CloudFront. A baseline WebACL is created when empty."
  type        = string
  default     = ""
}

variable "is_ipv6_enabled" {
  description = "Enable IPv6 for CloudFront"
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "http_version" {
  description = "HTTP version for CloudFront"
  type        = string
  default     = "http2and3"
}

variable "default_allowed_methods" {
  description = "Default allowed HTTP methods"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "default_cached_methods" {
  description = "Default cached HTTP methods"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "enable_compression" {
  description = "Enable compression in CloudFront"
  type        = bool
  default     = true
}

variable "viewer_protocol_policy" {
  description = "Viewer protocol policy"
  type        = string
  default     = "redirect-to-https"
}

variable "index_path_pattern" {
  description = "Path pattern for index.html cache behavior"
  type        = string
  default     = "/index.html"
}

# API Cache Behavior
variable "api_path_pattern" {
  description = "Path pattern for API cache behavior"
  type        = string
  default     = "/api/*"
}

variable "api_allowed_methods" {
  description = "Allowed HTTP methods for API"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
}

variable "api_viewer_protocol_policy" {
  description = "Viewer protocol policy for API"
  type        = string
  default     = "https-only"
}

# Custom Error Responses - Dynamic
variable "custom_error_responses" {
  description = "Custom error responses for CloudFront"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  ]
}

# Geo Restriction
variable "geo_restriction_type" {
  description = "Geo restriction type"
  type        = string
  default     = "none"
}

# Viewer Certificate
variable "ssl_support_method" {
  description = "SSL support method"
  type        = string
  default     = "sni-only"
}

variable "minimum_protocol_version" {
  description = "Minimum TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}
