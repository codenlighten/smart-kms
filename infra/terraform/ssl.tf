# SSL Certificate and DNS Configuration

# ACM Certificate
resource "aws_acm_certificate" "main" {
  count = var.environment == "production" && var.domain_name != "" ? 1 : 0
  
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-cert"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Route 53 Hosted Zone (if managing DNS)
resource "aws_route53_zone" "main" {
  count = var.environment == "production" && var.domain_name != "" && var.manage_dns ? 1 : 0
  
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-zone"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Route 53 Record for Certificate Validation
resource "aws_route53_record" "cert_validation" {
  for_each = var.environment == "production" && var.domain_name != "" && var.manage_dns ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  count = var.environment == "production" && var.domain_name != "" && var.manage_dns ? 1 : 0
  
  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# Route 53 A Record for ALB
resource "aws_route53_record" "main" {
  count = var.environment == "production" && var.domain_name != "" && var.manage_dns ? 1 : 0
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

# Route 53 Health Check
resource "aws_route53_health_check" "main" {
  count = var.environment == "production" && var.domain_name != "" && var.manage_dns ? 1 : 0
  
  fqdn                    = var.domain_name
  port                    = 443
  type                    = "HTTPS"
  resource_path           = "/v1/health"
  failure_threshold       = "3"
  request_interval        = "30"
  measure_latency         = true
  cloudwatch_alarm_region = var.region

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-health-check"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# CloudWatch Alarm for Route 53 Health Check
resource "aws_cloudwatch_metric_alarm" "route53_health_check" {
  count = var.environment == "production" && var.domain_name != "" && var.manage_dns ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.tenant_id}-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors Route53 health check"
  alarm_actions       = var.alert_email != "" ? [aws_sns_topic.alerts[0].arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.main[0].id
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-health-check-alarm"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}
