variable "region" { 
  type    = string
  default = "us-east-1" 
}

variable "project_name" { 
  type = string 
}

variable "tenant_id" { 
  type = string 
}

variable "create_artifacts_bucket" { 
  type    = bool
  default = false 
}

# Production-specific variables
variable "environment" {
  description = "Environment name (development/production)"
  type        = string
  default     = "development"
}

variable "domain_name" {
  description = "Domain name for the API (leave empty for development)"
  type        = string
  default     = ""
}

variable "manage_dns" {
  description = "Whether to manage DNS with Route 53"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Enable AWS WAF for API protection"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "blocked_countries" {
  description = "List of country codes to block in WAF"
  type        = list(string)
  default     = ["XX"]  # Placeholder country code
}
