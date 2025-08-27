# Monitoring module for ECS service observability and alerting
# Includes CloudWatch alarms, log metric filters, and optional SNS notifications

# SNS topic for alerts (optional)
resource "aws_sns_topic" "alerts" {
  count = var.sns_topic_name != null ? 1 : 0
  
  name = var.sns_topic_name
  
  tags = {
    Name        = var.sns_topic_name
    Environment = var.environment
    Purpose     = "ECS-Alerts"
  }
}

# CloudWatch metric filter for container pull errors
resource "aws_cloudwatch_log_metric_filter" "container_pull_errors" {
  name           = "${var.name_prefix}-container-pull-errors"
  pattern        = "CannotPullContainerError"
  log_group_name = var.log_group_name
  
  metric_transformation {
    name      = "${var.name_prefix}/ContainerPullErrors"
    namespace = "ECS/CustomMetrics"
    value     = "1"
  }
}

# CloudWatch metric filter for task failures  
resource "aws_cloudwatch_log_metric_filter" "task_failures" {
  name           = "${var.name_prefix}-task-failures"
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"
  log_group_name = var.log_group_name
  
  metric_transformation {
    name      = "${var.name_prefix}/TaskFailures"
    namespace = "ECS/CustomMetrics"
    value     = "1"
  }
}

# Alarm: ECS Service - Unhealthy hosts
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy ALB targets"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }
  
  tags = {
    Name        = "${var.name_prefix}-unhealthy-hosts-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: ECS Service - Running task count below desired
resource "aws_cloudwatch_metric_alarm" "ecs_service_running_count" {
  alarm_name          = "${var.name_prefix}-ecs-running-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = var.minimum_running_tasks
  alarm_description   = "This metric monitors ECS service running task count"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }
  
  tags = {
    Name        = "${var.name_prefix}-ecs-running-count-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: ALB - 5XX errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }
  
  tags = {
    Name        = "${var.name_prefix}-alb-5xx-errors-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: ALB - High response time
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.name_prefix}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.response_time_threshold
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }
  
  tags = {
    Name        = "${var.name_prefix}-alb-response-time-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: Container pull errors (custom metric)
resource "aws_cloudwatch_metric_alarm" "container_pull_errors" {
  alarm_name          = "${var.name_prefix}-container-pull-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "${var.name_prefix}/ContainerPullErrors"
  namespace           = "ECS/CustomMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors container pull errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  treat_missing_data  = "notBreaching"
  
  tags = {
    Name        = "${var.name_prefix}-container-pull-errors-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: ECS CPU utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }
  
  tags = {
    Name        = "${var.name_prefix}-ecs-cpu-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Alarm: ECS Memory utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    ServiceName = var.service_name
    ClusterName = var.cluster_name
  }
  
  tags = {
    Name        = "${var.name_prefix}-ecs-memory-alarm"
    Environment = var.environment
    Service     = var.service_name
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0
  
  dashboard_name = "${var.name_prefix}-${var.service_name}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.service_name, "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            ["ECS/ContainerInsights", "RunningTaskCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ECS Service Metrics"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.load_balancer_arn_suffix],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", ".", "."],
            [".", "HealthyHostCount", ".", ".", ".", "."],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Metrics"
          view   = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}
