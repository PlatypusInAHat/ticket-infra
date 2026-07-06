terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_zone_settings_override" "main" {
  zone_id = var.cloudflare_zone_id

  settings {
    always_use_https = var.zone_setting_always_use_https
    brotli           = var.zone_setting_brotli
    http2            = var.zone_setting_http2
    http3            = var.zone_setting_http3
    min_tls_version  = var.zone_setting_min_tls_version
    security_level   = var.security_level
    ssl              = var.zone_setting_ssl
  }
}

resource "cloudflare_record" "records" {
  for_each = var.dns_records

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  value   = each.value.value
  type    = each.value.type
  proxied = each.value.proxied
}

resource "cloudflare_ruleset" "waf_custom" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.environment}-custom-waf"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  dynamic "rules" {
    for_each = var.waf_custom_rules
    content {
      action      = rules.value.action
      expression  = rules.value.expression
      description = rules.value.description
      enabled     = rules.value.enabled
    }
  }
}

resource "cloudflare_ruleset" "rate_limits" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.environment}-api-rate-limits"
  kind    = "zone"
  phase   = "http_ratelimit"

  dynamic "rules" {
    for_each = var.rate_limit_rules
    content {
      action      = rules.value.action
      description = rules.value.description
      enabled     = rules.value.enabled
      expression  = rules.value.expression

      ratelimit {
        characteristics     = rules.value.ratelimit.characteristics
        period              = rules.value.ratelimit.period
        requests_per_period = rules.value.ratelimit.requests_per_period
        mitigation_timeout  = rules.value.ratelimit.mitigation_timeout
      }
    }
  }
}
