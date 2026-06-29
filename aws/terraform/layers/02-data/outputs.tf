output "mongodb_cluster_id" {
  description = "MongoDB cluster ID"
  value       = module.mongodb_atlas.cluster_id
}

output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = module.mongodb_atlas.cluster_connection_string
  sensitive   = true
}

output "mongodb_srv_connection_string" {
  description = "MongoDB SRV connection string"
  value       = module.mongodb_atlas.cluster_srv_connection_string
  sensitive   = true
}

output "mq_broker_id" {
  description = "MQ broker ID"
  value       = module.amazon_mq.broker_id
}

output "mq_broker_arn" {
  description = "MQ broker ARN"
  value       = module.amazon_mq.broker_arn
}

output "mq_broker_endpoint" {
  description = "MQ broker endpoint"
  value       = module.amazon_mq.broker_endpoint
}

output "mq_broker_ip_address" {
  description = "MQ broker IP address"
  value       = module.amazon_mq.broker_ip_address
}

output "mq_connection_string" {
  description = "MQ connection string"
  value       = module.amazon_mq.broker_connection_string
  sensitive   = true
}
