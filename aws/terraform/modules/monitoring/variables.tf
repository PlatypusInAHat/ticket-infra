variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 365
}

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# SNS Configuration
variable "sns_kms_key_id" {
  description = "KMS key ID for SNS encryption"
  type        = string
  default     = null
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for monitoring KMS keys"
  type        = number
  default     = 7
}

variable "sns_protocol" {
  description = "SNS subscription protocol"
  type        = string
  default     = "email"
}

variable "iam_policy_version" {
  description = "IAM policy document version"
  type        = string
  default     = "2012-10-17"
}

# Log Groups
variable "log_group_names" {
  description = "List of CloudWatch log group names"
  type        = list(string)
  default = [
    "/aws/eks/cluster",
    "/aws/eks/application",
    "/aws/alb"
  ]
}

# CloudWatch Alarms Configuration
variable "treat_missing_data" {
  description = "How to treat missing data in alarms"
  type        = string
  default     = "notBreaching"
}

variable "metric_alarms" {
  description = "List of metric alarms to create"
  type = list(object({
    name                = string
    comparison_operator = string
    evaluation_periods  = string
    metric_name         = string
    namespace           = string
    period              = number
    statistic           = string
    threshold           = number
    description         = string
  }))
  default = [
    {
      name                = "eks-cpu-high"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name         = "cpu_utilization"
      namespace           = "EKS"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      description         = "Alert when EKS CPU is high"
    },
    {
      name                = "eks-memory-high"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name         = "memory_utilization"
      namespace           = "EKS"
      period              = 300
      statistic           = "Average"
      threshold           = 85
      description         = "Alert when EKS memory is high"
    },
    {
      name                = "alb-high-latency"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "3"
      metric_name         = "TargetResponseTime"
      namespace           = "AWS/ApplicationELB"
      period              = 60
      statistic           = "Average"
      threshold           = 1
      description         = "Alert when ALB response time is high"
    },
    {
      name                = "alb-unhealthy-targets"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name         = "UnHealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Average"
      threshold           = 0
      description         = "Alert when ALB has unhealthy targets"
    },
    {
      name                = "high-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name         = "ErrorCount"
      namespace           = "Application"
      period              = 300
      statistic           = "Sum"
      threshold           = 50
      description         = "Alert when error rate is high"
    }
  ]
}

# Log Metric Filters
variable "log_metric_filters" {
  description = "List of log metric filters to create"
  type = list(object({
    name           = string
    log_group      = string
    filter_pattern = string
    metric_name    = string
    namespace      = string
    value          = string
  }))
  default = [
    {
      name           = "5xx-errors"
      log_group      = "/aws/alb"
      filter_pattern = "[... , status = 5*, ...]"
      metric_name    = "HTTP5XXErrors"
      namespace      = "Application"
      value          = "1"
    },
    {
      name           = "high-latency"
      log_group      = "/aws/alb"
      filter_pattern = "[... , response_time > 1000, ...]"
      metric_name    = "HighLatencyRequests"
      namespace      = "Application"
      value          = "1"
    }
  ]
}

# Dashboard Widgets
variable "dashboard_widgets" {
  description = "List of CloudWatch dashboard widgets"
  type        = any
  default = [
    {
      type = "metric"
      properties = {
        metrics = [
          ["AWS/EKS", "cluster_node_count", { stat = "Average" }],
          [".", "cluster_cpu_utilization", { stat = "Average" }],
          [".", "cluster_memory_utilization", { stat = "Average" }]
        ]
        period = 300
        stat   = "Average"
        title  = "EKS Cluster Health"
        yAxis = {
          left = {
            min = 0
            max = 100
          }
        }
      }
    },
    {
      type = "metric"
      properties = {
        metrics = [
          ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
          [".", "RequestCount", { stat = "Sum" }],
          [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
        ]
        period = 60
        stat   = "Average"
        title  = "ALB Performance"
      }
    },
    {
      type = "log"
      properties = {
        query = "fields @timestamp, @message | stats count() by @logStream"
        title = "Application Error Count"
      }
    }
  ]
}
