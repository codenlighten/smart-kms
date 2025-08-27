# Application Load Balancer
resource "aws_lb" "main" {
  count = var.environment == "production" ? 1 : 0
  
  name               = "${var.project_name}-${var.tenant_id}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2              = true
  idle_timeout              = 60

  access_logs {
    bucket  = aws_s3_bucket.alb_logs[0].id
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-alb"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# S3 Bucket for ALB Access Logs
resource "aws_s3_bucket" "alb_logs" {
  count = var.environment == "production" ? 1 : 0
  
  bucket        = "${var.project_name}-${lower(var.tenant_id)}-alb-logs-${random_string.bucket_suffix[0].result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-alb-logs"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  count = var.environment == "production" ? 1 : 0
  
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.environment == "production" ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.environment == "production" ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.anchor.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.environment == "production" ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for ALB Access Logs
data "aws_elb_service_account" "main" {
  count = var.environment == "production" ? 1 : 0
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.environment == "production" ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main[0].arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      }
    ]
  })
}

# Target Group for Sign Service
resource "aws_lb_target_group" "sign_service" {
  count = var.environment == "production" ? 1 : 0
  
  name        = "uf-${var.tenant_id}-sign-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main[0].id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/v1/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-sign-tg"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ALB Listener for HTTP (redirect to HTTPS)
resource "aws_lb_listener" "sign_service_http" {
  count = var.environment == "production" ? 1 : 0
  
  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB Listener for HTTPS
resource "aws_lb_listener" "sign_service_https" {
  count = var.environment == "production" ? 1 : 0
  
  load_balancer_arn = aws_lb.main[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.domain_name != "" ? aws_acm_certificate.main[0].arn : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sign_service[0].arn
  }
}

# Default self-signed certificate if no domain provided
resource "aws_acm_certificate" "default" {
  count = var.environment == "production" && var.domain_name == "" ? 1 : 0
  
  domain_name       = "${var.project_name}-${var.tenant_id}.example.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-default-cert"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}
