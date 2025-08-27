# ECR Repository for Sign Service
resource "aws_ecr_repository" "sign_service" {
  count = var.environment == "production" ? 1 : 0
  
  name                 = "${var.project_name}-${lower(var.tenant_id)}-sign-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-sign-service"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "sign_service" {
  count = var.environment == "production" ? 1 : 0
  
  repository = aws_ecr_repository.sign_service[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  count = var.environment == "production" ? 1 : 0
  
  name = "${var.project_name}-${var.tenant_id}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-cluster"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  count = var.environment == "production" ? 1 : 0
  
  cluster_name = aws_ecs_cluster.main[0].name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  count = var.environment == "production" ? 1 : 0
  
  name              = "/ecs/${var.project_name}-${var.tenant_id}-sign-service"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecs-logs"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "sign_service" {
  count = var.environment == "production" ? 1 : 0
  
  family                   = "${var.project_name}-${var.tenant_id}-sign-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role[0].arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "sign-service"
      image = "${aws_ecr_repository.sign_service[0].repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "TENANT_ID"
          value = var.tenant_id
        },
        {
          name  = "RECEIPTS_TABLE"
          value = aws_dynamodb_table.receipts.name
        },
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs[0].name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8080/v1/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-sign-service-task"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "sign_service" {
  count = var.environment == "production" ? 1 : 0
  
  name            = "${var.project_name}-${var.tenant_id}-sign-service"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.sign_service[0].arn
  desired_count   = 2
  launch_type     = "FARGATE"
  
  platform_version = "LATEST"
  
  enable_execute_command = true  # For debugging

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sign_service[0].arn
    container_name   = "sign-service"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 300

  # Remove deployment_configuration for now to ensure compatibility

  depends_on = [
    aws_lb_listener.sign_service_https,
    aws_iam_role_policy_attachment.ecs_execution_role_policy,
    aws_iam_role_policy_attachment.ecs_task_role_policy
  ]

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-sign-service"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  count = var.environment == "production" ? 1 : 0
  
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main[0].name}/${aws_ecs_service.sign_service[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  count = var.environment == "production" ? 1 : 0
  
  name               = "${var.project_name}-${var.tenant_id}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60.0
    
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  count = var.environment == "production" ? 1 : 0
  
  name               = "${var.project_name}-${var.tenant_id}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70.0
    
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}
