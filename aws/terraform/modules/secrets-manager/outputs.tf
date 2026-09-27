output "mongodb_connection_string_arn" {
  description = "ARN of MongoDB connection string secret"
  value       = aws_secretsmanager_secret.mongodb_connection_string.arn
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "rabbitmq_credentials_arn" {
  description = "ARN of RabbitMQ credentials secret"
  value       = aws_secretsmanager_secret.rabbitmq_credentials.arn
}

output "redis_url_arn" {
  description = "ARN of the managed Redis URL secret"
  value       = try(aws_secretsmanager_secret.redis_url[0].arn, "")
}

output "payment_credentials_arn" {
  description = "ARN of payment credentials secret"
  value       = try(aws_secretsmanager_secret.payment_credentials[0].arn, "")
}

output "email_credentials_arn" {
  description = "ARN of email credentials secret"
  value       = try(aws_secretsmanager_secret.email_credentials[0].arn, "")
}

output "secrets_arns" {
  description = "Map of all secret ARNs"
  value = {
    mongodb_connection_string = aws_secretsmanager_secret.mongodb_connection_string.arn
    jwt_secret                = aws_secretsmanager_secret.jwt_secret.arn
    rabbitmq_credentials      = aws_secretsmanager_secret.rabbitmq_credentials.arn
    redis_url                 = try(aws_secretsmanager_secret.redis_url[0].arn, "")
    payment_credentials       = try(aws_secretsmanager_secret.payment_credentials[0].arn, "")
    email_credentials         = try(aws_secretsmanager_secret.email_credentials[0].arn, "")
  }
}
