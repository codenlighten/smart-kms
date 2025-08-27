# CloudWatch Monitoring and Alarms

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  count = var.environment == "production" && var.alert_email != "" ? 1 : 0
  
  name = "${var.project_name}-${var.tenant_id}-alerts"

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-alerts"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.environment == "production" && var.alert_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count = var.environment == "production" ? 1 : 0
  
  dashboard_name = "${var.project_name}-${var.tenant_id}-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.sign_service[0].name, "ClusterName", aws_ecs_cluster.main[0].name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ECS Service Metrics"
          period  = 300
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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main[0].arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "ServiceCount", "ServiceName", aws_ecs_service.sign_service[0].name, "ClusterName", aws_ecs_cluster.main[0].name],
            [".", "RunningTaskCount", ".", ".", ".", "."],
            [".", "PendingTaskCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ECS Task Counts"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.ecs[0].name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.region
          title   = "Recent Logs"
          view    = "table"
        }
      }
    ]
  })
}

# CloudWatch Alarms

# High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.sign_service[0].name
    ClusterName = aws_ecs_cluster.main[0].name
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-high-cpu-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# High Memory Utilization
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.sign_service[0].name
    ClusterName = aws_ecs_cluster.main[0].name
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-high-memory-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ALB 5XX Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main[0].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-alb-5xx-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Target 5XX Errors
resource "aws_cloudwatch_metric_alarm" "target_5xx_errors" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors target 5XX errors"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main[0].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-target-5xx-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# High Response Time
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main[0].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-response-time-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Unhealthy Target Count
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  count = var.environment == "production" ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy targets"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.sign_service[0].arn_suffix
    LoadBalancer = aws_lb.main[0].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-unhealthy-targets-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# WAF Blocked Requests (if WAF is enabled)
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.environment == "production" && var.enable_waf ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors WAF blocked requests"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = var.region
    Rule   = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-waf-blocked-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}
