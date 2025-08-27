# AWS WAF for API Protection

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.environment == "production" && var.enable_waf ? 1 : 0
  
  name  = "${var.project_name}-${var.tenant_id}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "${var.project_name}-${var.tenant_id}-rate-limit"
      sampled_requests_enabled    = true
    }
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCore"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "${var.project_name}-${var.tenant_id}-core-rules"
      sampled_requests_enabled    = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "${var.project_name}-${var.tenant_id}-bad-inputs"
      sampled_requests_enabled    = true
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "AWSManagedRulesSQLi"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "${var.project_name}-${var.tenant_id}-sqli"
      sampled_requests_enabled    = true
    }
  }

  # Geo-blocking rule disabled for global access
  # rule {
  #   name     = "GeoBlockingRule"
  #   priority = 5

  #   action {
  #     block {}
  #   }

  #   statement {
  #     geo_match_statement {
  #       country_codes = var.blocked_countries
  #     }
  #   }

  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                 = "${var.project_name}-${var.tenant_id}-geo-block"
  #     sampled_requests_enabled    = true
  #   }
  # }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "${var.project_name}-${var.tenant_id}-waf"
    sampled_requests_enabled    = true
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-waf"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  count = var.environment == "production" && var.enable_waf ? 1 : 0
  
  resource_arn = aws_lb.main[0].arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf" {
  count = var.environment == "production" ? 1 : 0
  
  name              = "/aws/wafv2/${var.project_name}-${var.tenant_id}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-waf-logs"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.environment == "production" && var.enable_waf ? 1 : 0
  
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.waf[0].name}"]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "x-api-key"
    }
  }
}
