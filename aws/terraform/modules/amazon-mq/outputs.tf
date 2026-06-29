output "broker_id" {
  description = "MQ broker ID"
  value       = aws_mq_broker.rabbitmq.id
}

output "broker_arn" {
  description = "MQ broker ARN"
  value       = aws_mq_broker.rabbitmq.arn
}

output "broker_endpoint" {
  description = "MQ broker endpoint"
  value       = aws_mq_broker.rabbitmq.instances[0].console_url
}

output "broker_amqp_endpoint" {
  description = "MQ broker AMQP endpoint"
  value       = "amqp://${var.admin_username}:***@${aws_mq_broker.rabbitmq.instances[0].ip_address}:5672"
  sensitive   = true
}

output "broker_connection_string" {
  description = "Connection string for applications"
  value       = "amqp://${var.admin_username}:***@${aws_mq_broker.rabbitmq.instances[0].ip_address}:5672/"
  sensitive   = true
}

output "broker_ip_address" {
  description = "Broker IP address"
  value       = aws_mq_broker.rabbitmq.instances[0].ip_address
}

output "security_group_id" {
  description = "Security group ID for MQ"
  value       = aws_security_group.mq.id
}
