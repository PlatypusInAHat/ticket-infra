# Monitoring Module
# Creates CloudWatch Log Groups, alarms, and SNS topics for monitoring

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  name_prefix       = "${var.environment}-alarms-"
  kms_master_key_id = var.sns_kms_key_id

  tags = var.tags
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = var.sns_protocol
  endpoint  = var.alert_email
}

# CloudWatch Log Groups - Dynamic creation
resource "aws_cloudwatch_log_group" "log_groups" {
  for_each          = toset(var.log_group_names)
  name              = each.value
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-overview"

  dashboard_body = jsonencode({
    widgets = [
      for widget in var.dashboard_widgets : {
        type       = widget.type
        properties = widget.properties
      }
    ]
  })
}

# CloudWatch Alarms - Dynamic creation
resource "aws_cloudwatch_metric_alarm" "metric_alarms" {
  for_each            = { for alarm in var.metric_alarms : alarm.name => alarm }
  alarm_name          = "${var.environment}-${each.value.name}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.description
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = var.treat_missing_data

  tags = var.tags
}

# CloudWatch Log Metric Filters - Dynamic creation
resource "aws_cloudwatch_log_metric_filter" "log_filters" {
  for_each       = { for filter in var.log_metric_filters : filter.name => filter }
  name           = "${var.environment}-${each.value.name}"
  log_group_name = aws_cloudwatch_log_group.log_groups[each.value.log_group].name
  filter_pattern = each.value.filter_pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = each.value.namespace
    value     = each.value.value
  }
}