output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.sns_topic_name != null ? aws_sns_topic.alerts[0].arn : null
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.create_dashboard ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
}

output "alarm_names" {
  description = "Names of all created CloudWatch alarms"
  value = [
    aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_service_running_count.alarm_name,
    aws_cloudwatch_metric_alarm.alb_5xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.alb_response_time.alarm_name,
    aws_cloudwatch_metric_alarm.container_pull_errors.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_cpu_utilization.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_memory_utilization.alarm_name
  ]
}

output "metric_filter_names" {
  description = "Names of all created log metric filters"
  value = [
    aws_cloudwatch_log_metric_filter.container_pull_errors.name,
    aws_cloudwatch_log_metric_filter.task_failures.name
  ]
}
