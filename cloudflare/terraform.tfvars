# Cloudflare configuration

environment = "ticketstage"

# Note: Set these in your environment or terraform.tfvars.local
# cloudflare_api_token = "..."
# cloudflare_zone_id = "..."

security_level = "medium"

dns_records = {
  api = {
    name    = "api"
    value   = "api-alb-hostname.aws.com" # Replace with actual AWS ALB hostname
    type    = "CNAME"
    proxied = true
  }
  web = {
    name    = "www"
    value   = "frontend-cloudfront.aws.com" # Replace with actual CloudFront or frontend ALB hostname
    type    = "CNAME"
    proxied = true
  }
}
