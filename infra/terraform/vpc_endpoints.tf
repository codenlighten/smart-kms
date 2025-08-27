# VPC Endpoints Configuration for Zero-Trust Architecture

# VPC Endpoint for KMS
resource "aws_vpc_endpoint" "kms" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "kms:Sign",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = aws_iam_role.ecs_task_role.arn
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-kms-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private[0].id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.receipts.arn
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = aws_iam_role.ecs_task_role.arn
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-dynamodb-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecr-api-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for ECR Docker
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecr-dkr-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-logs-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for CloudWatch Monitoring
resource "aws_vpc_endpoint" "monitoring" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-monitoring-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private[0].id]

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-s3-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for ECS
resource "aws_vpc_endpoint" "ecs" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecs-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for ECS Agent
resource "aws_vpc_endpoint" "ecs_agent" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecs-agent-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# VPC Endpoint for ECS Telemetry
resource "aws_vpc_endpoint" "ecs_telemetry" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${var.region}.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecs-telemetry-vpce"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}
