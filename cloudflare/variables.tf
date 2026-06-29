variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Zone DNS and ruleset permissions."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone id."
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "ticketstage"
}

variable "security_level" {
  type        = string
  default     = "medium"
  description = "Cloudflare security level. Use high during big ticket launches."
}

variable "zone_setting_always_use_https" {
  type        = string
  default     = "on"
  description = "Always use HTTPS zone setting"
}

variable "zone_setting_brotli" {
  type        = string
  default     = "on"
  description = "Brotli zone setting"
}

variable "zone_setting_http2" {
  type        = string
  default     = "on"
  description = "HTTP/2 zone setting"
}

variable "zone_setting_http3" {
  type        = string
  default     = "on"
  description = "HTTP/3 zone setting"
}

variable "zone_setting_min_tls_version" {
  type        = string
  default     = "1.2"
  description = "Minimum TLS version zone setting"
}

variable "zone_setting_ssl" {
  type        = string
  default     = "strict"
  description = "SSL mode zone setting"
}

variable "dns_records" {
  type = map(object({
    name    = string
    value   = string
    type    = string
    proxied = bool
  }))
  description = "DNS records to create"
  default     = {}
}

variable "waf_custom_rules" {
  type = list(object({
    action      = string
    expression  = string
    description = string
    enabled     = bool
  }))
  description = "Custom WAF rules"
  default = [
    {
      action      = "block"
      expression  = "(http.request.uri.path contains \"/.env\" or http.request.uri.path contains \"/wp-admin\" or http.request.uri.path contains \"/phpmyadmin\")"
      description = "Block common scanner paths"
      enabled     = true
    },
    {
      action      = "managed_challenge"
      expression  = "(http.request.uri.path in {\"/api/bookings\" \"/api/payment/session\" \"/api/payment/process\"})"
      description = "Challenge sensitive checkout endpoints"
      enabled     = true
    }
  ]
}

variable "rate_limit_rules" {
  type = list(object({
    action      = string
    description = string
    enabled     = bool
    expression  = string
    ratelimit = object({
      characteristics     = list(string)
      period              = number
      requests_per_period = number
      mitigation_timeout  = number
    })
  }))
  description = "Rate limiting rules"
  default = [
    {
      action      = "managed_challenge"
      description = "Limit login brute force"
      enabled     = true
      expression  = "(http.request.uri.path eq \"/api/auth/login\")"
      ratelimit = {
        characteristics     = ["ip.src"]
        period              = 60
        requests_per_period = 10
        mitigation_timeout  = 600
      }
    },
    {
      action      = "managed_challenge"
      description = "Limit booking spam"
      enabled     = true
      expression  = "(http.request.uri.path eq \"/api/bookings\")"
      ratelimit = {
        characteristics     = ["ip.src"]
        period              = 60
        requests_per_period = 8
        mitigation_timeout  = 300
      }
    }
  ]
}
