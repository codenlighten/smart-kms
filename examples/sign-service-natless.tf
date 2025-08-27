# Example implementation using the NAT-less ECS modules
# This demonstrates how to deploy the sign service with the new architecture

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "AWS-KMS-Scaffold"
      Environment = var.environment
      Tenant      = var.tenant_id
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "universal-foundation-${var.environment}"
  
  # Container image URI (update with your actual ECR repository)
  container_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/universal-foundation-${lower(var.environment)}-sign-service:latest"
  
  # Common environment variables
  environment_variables = {
    AWS_REGION      = data.aws_region.current.name
    RECEIPTS_TABLE  = module.dynamodb.table_name
    TENANT_ID       = var.tenant_id
    PORT            = "8080"
    NODE_ENV        = var.environment == "PROD" ? "production" : "development"
  }
}

# Networking module - NAT-less VPC with endpoints
module "networking" {
  source = "./modules/networking"
  
  name_prefix               = local.name_prefix
  environment              = var.environment
  tenant_id                = var.tenant_id
  region                   = data.aws_region.current.name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  container_port           = 8080
  enable_secrets_manager   = var.enable_secrets_manager
}

# DynamoDB table for receipts
module "dynamodb" {
  source = "./modules/dynamodb"  # You'll need to create this module
  
  name_prefix     = local.name_prefix
  environment     = var.environment
  table_name      = "receipts"
  kms_key_arn     = module.kms.key_arn
  enable_streams  = true
  
  tags = {
    Purpose = "Policy receipts storage"
  }
}

# KMS key for encryption
module "kms" {
  source = "./modules/kms"  # You'll need to create this module
  
  name_prefix  = local.name_prefix
  environment  = var.environment
  description  = "KMS key for ${local.name_prefix} encryption"
  
  # Allow the ECS task role to use the key
  key_users = [
    # Will be populated after ECS service module creates the role
  ]
}

# ECS service module
module "ecs_service" {
  source = "./modules/ecs_service"
  
  name_prefix              = local.name_prefix
  environment              = var.environment
  service_name             = "sign-service"
  container_image          = local.container_image
  container_port           = 8080
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  desired_count            = var.ecs_desired_count
  
  # Networking
  vpc_id                   = module.networking.vpc_id
  public_subnet_ids        = module.networking.public_subnet_ids
  private_subnet_ids       = module.networking.private_subnet_ids
  ecs_security_group_id    = module.networking.ecs_tasks_security_group_id
  alb_security_group_id    = module.networking.alb_security_group_id
  
  # IAM permissions
  dynamodb_table_arn       = module.dynamodb.table_arn
  kms_key_arn             = module.kms.key_arn
  
  # Configuration
  environment_variables    = local.environment_variables
  health_check_path       = "/health"
  health_check_command    = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
  certificate_arn         = var.certificate_arn
  log_retention_days      = var.log_retention_days
  enable_container_insights = true
  enable_deletion_protection = var.environment == "PROD"
  enable_ecs_exec         = var.enable_ecs_exec
}

# Monitoring module
module "monitoring" {
  source = "./modules/monitoring"
  
  name_prefix              = local.name_prefix
  environment              = var.environment
  service_name             = "sign-service"
  cluster_name             = module.ecs_service.ecs_cluster_id
  region                   = data.aws_region.current.name
  log_group_name          = module.ecs_service.log_group_name
  target_group_arn_suffix = split("/", module.ecs_service.target_group_arn)[1]
  load_balancer_arn_suffix = split("/", module.ecs_service.alb_arn)[1]
  
  # Alert configuration
  sns_topic_name          = var.enable_alerts ? "${local.name_prefix}-alerts" : null
  minimum_running_tasks   = var.ecs_desired_count
  response_time_threshold = var.response_time_threshold
  cpu_threshold          = var.cpu_threshold
  memory_threshold       = var.memory_threshold
  create_dashboard       = var.create_dashboard
}

# Update KMS key policy to include ECS task role
resource "aws_kms_key_policy" "main" {
  key_id = module.kms.key_id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECS Task Role"
        Effect = "Allow"
        Principal = {
          AWS = module.ecs_service.task_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}
