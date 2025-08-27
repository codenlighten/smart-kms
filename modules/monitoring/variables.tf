variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (PROD, DEV, etc.)"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for ALB metrics"
  type        = string
}

variable "load_balancer_arn_suffix" {
  description = "Load balancer ARN suffix for ALB metrics"
  type        = string
}

variable "sns_topic_name" {
  description = "SNS topic name for alerts (optional, creates topic if provided)"
  type        = string
  default     = null
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts (optional, uses existing topic)"
  type        = string
  default     = null
}

variable "minimum_running_tasks" {
  description = "Minimum number of running tasks threshold"
  type        = number
  default     = 1
}

variable "response_time_threshold" {
  description = "ALB response time threshold in seconds"
  type        = number
  default     = 2.0
}

variable "cpu_threshold" {
  description = "ECS CPU utilization threshold percentage"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "ECS memory utilization threshold percentage"
  type        = number
  default     = 80
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}
