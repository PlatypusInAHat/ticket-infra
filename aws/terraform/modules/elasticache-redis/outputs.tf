output "replication_group_id" {
  description = "Redis replication group ID"
  value       = try(aws_elasticache_replication_group.redis[0].id, "")
}

output "endpoint" {
  description = "Redis primary endpoint"
  value       = try(aws_elasticache_replication_group.redis[0].primary_endpoint_address, "")
}

output "port" {
  description = "Redis port"
  value       = var.port
}

output "security_group_id" {
  description = "Redis security group ID"
  value       = try(aws_security_group.redis[0].id, "")
}

output "redis_url" {
  description = "TLS Redis URL for application secret injection"
  sensitive   = true
  value = var.enable_redis ? format(
    "rediss://:%s@%s:%d",
    urlencode(var.auth_token),
    aws_elasticache_replication_group.redis[0].primary_endpoint_address,
    var.port
  ) : ""
}
