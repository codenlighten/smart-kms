# ECS Service module for NAT-less Fargate deployment
# Includes proper IAM roles, task definition, service, and ALB integration

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for ECS task execution (ECR pulls, CloudWatch logs)
data "aws_iam_policy_document" "ecs_execution_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.name_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_trust.json
  
  tags = {
    Name        = "${var.name_prefix}-ecs-execution-role"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional execution role policy for KMS if needed
resource "aws_iam_role_policy" "ecs_execution_kms" {
  count = var.kms_key_arn != null ? 1 : 0
  
  name = "${var.name_prefix}-ecs-execution-kms"
  role = aws_iam_role.ecs_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM role for ECS tasks (application permissions)
resource "aws_iam_role" "ecs_task" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_trust.json
  
  tags = {
    Name        = "${var.name_prefix}-ecs-task-role"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Task role policy for application-specific permissions
resource "aws_iam_role_policy" "ecs_task_app" {
  name = "${var.name_prefix}-ecs-task-app"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem", 
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = var.dynamodb_table_arn
        }
      ],
      var.kms_key_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:DescribeKey"
          ]
          Resource = var.kms_key_arn
          Condition = {
            StringEquals = {
              "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
            }
          }
        }
      ] : []
    )
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
  
  tags = {
    Name        = "${var.name_prefix}-cluster"
    Environment = var.environment
  }
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}-${var.service_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.name_prefix}-${var.service_name}-logs"
    Environment = var.environment
    Service     = var.service_name
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        for k, v in var.environment_variables : {
          name  = k
          value = v
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = var.health_check_command != null ? {
        command     = var.health_check_command
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      } : null
    }
  ])
  
  tags = {
    Name        = "${var.name_prefix}-${var.service_name}-task"
    Environment = var.environment
    Service     = var.service_name
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = var.enable_deletion_protection
  
  tags = {
    Name        = "${var.name_prefix}-alb"
    Environment = var.environment
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }
  
  tags = {
    Name        = "${var.name_prefix}-${var.service_name}-tg"
    Environment = var.environment
    Service     = var.service_name
  }
}

# ALB Listener (HTTP - redirect to HTTPS if certificate provided)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"
    
    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    dynamic "forward" {
      for_each = var.certificate_arn == null ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.app.arn
        }
      }
    }
  }
  
  tags = {
    Name        = "${var.name_prefix}-http-listener"
    Environment = var.environment
  }
}

# ALB Listener (HTTPS - if certificate provided)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
  
  tags = {
    Name        = "${var.name_prefix}-https-listener"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-${var.service_name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false  # NAT-less - no public IP needed
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }
  
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
    
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }
  
  # Wait for target group to be created
  depends_on = [aws_lb_listener.http, aws_lb_listener.https]
  
  # Enable ECS Exec for debugging
  enable_execute_command = var.enable_ecs_exec
  
  tags = {
    Name        = "${var.name_prefix}-${var.service_name}"
    Environment = var.environment
    Service     = var.service_name
  }
}
