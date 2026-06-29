output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.cloudwatch_dashboard_url
}

output "log_group_names" {
  description = "Map of log group names"
  value       = module.monitoring.log_group_names
}

output "metric_alarm_names" {
  description = "Map of metric alarm names"
  value       = module.monitoring.metric_alarm_names
}
