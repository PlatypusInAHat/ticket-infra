output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "log_group_names" {
  description = "Map of log group names"
  value       = { for k, v in aws_cloudwatch_log_group.log_groups : k => v.name }
}

output "metric_alarm_names" {
  description = "Map of metric alarm names"
  value       = { for k, v in aws_cloudwatch_metric_alarm.metric_alarms : k => v.alarm_name }
}

output "logs_kms_key_arn" {
  description = "KMS key ARN used for CloudWatch log groups and observability secrets"
  value       = aws_kms_key.logs.arn
}
