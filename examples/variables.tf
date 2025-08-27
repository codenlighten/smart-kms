# Variables for the NAT-less ECS deployment example

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (PROD, DEV, STAGING)"
  type        = string
  default     = "PROD"
  
  validation {
    condition     = contains(["PROD", "DEV", "STAGING"], var.environment)
    error_message = "Environment must be one of: PROD, DEV, STAGING."
  }
}

variable "tenant_id" {
  description = "Tenant identifier"
  type        = string
  default     = "T123"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (ECS tasks, NAT-less)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ECS Configuration
variable "ecs_cpu" {
  description = "CPU units for ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "ecs_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
  
  validation {
    condition     = var.ecs_desired_count >= 1
    error_message = "Desired count must be at least 1."
  }
}

# SSL/TLS
variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = null
}

# Features
variable "enable_secrets_manager" {
  description = "Enable Secrets Manager VPC endpoint"
  type        = bool
  default     = false
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = true
}

variable "enable_alerts" {
  description = "Enable CloudWatch alerts and SNS notifications"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

# Monitoring thresholds
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

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch value."
  }
}
