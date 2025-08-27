# NAT-less VPC with comprehensive VPC endpoints for ECS Fargate
# Supports ECR pulls, logging, and AWS service access without NAT Gateway costs

locals {
  # Interface endpoints required for NAT-less ECS Fargate
  interface_endpoints = [
    "ecr.api",
    "ecr.dkr", 
    "logs",
    "sts",
    "kms",
    "ecs",
    "ecs-agent",
    "ecs-telemetry",
    "monitoring"
  ]
  
  # Optional endpoints (add secrets manager if using)
  optional_endpoints = var.enable_secrets_manager ? ["secretsmanager"] : []
  
  all_interface_endpoints = concat(local.interface_endpoints, local.optional_endpoints)
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.region}.s3"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.region}.dynamodb"
}

# VPC with DNS support for Private DNS endpoints
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Critical for VPC endpoints Private DNS
  enable_dns_support   = true  # Critical for VPC endpoints Private DNS
  
  tags = {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
    Tenant      = var.tenant_id
  }
}

# Internet Gateway for public subnets (ALB)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.name_prefix}-igw"
    Environment = var.environment
  }
}

# Public subnets for ALB
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.name_prefix}-public-${count.index + 1}"
    Environment = var.environment
    Type        = "public"
  }
}

# Private subnets for ECS tasks (NAT-less)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name        = "${var.name_prefix}-private-${count.index + 1}"
    Environment = var.environment
    Type        = "private"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.environment
  }
}

# Route table for private subnets (NAT-less with gateway endpoints)
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)
  
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.name_prefix}-private-rt-${count.index + 1}"
    Environment = var.environment
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpce"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  
  tags = {
    Name        = "${var.name_prefix}-vpce-sg"
    Environment = var.environment
  }
}

# S3 Gateway Endpoint (no additional cost)
resource "aws_vpc_endpoint" "s3" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = aws_route_table.private[*].id
  
  tags = {
    Name        = "${var.name_prefix}-s3-endpoint"
    Environment = var.environment
    Type        = "Gateway"
  }
}

# DynamoDB Gateway Endpoint (no additional cost)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = aws_route_table.private[*].id
  
  tags = {
    Name        = "${var.name_prefix}-dynamodb-endpoint"
    Environment = var.environment
    Type        = "Gateway"
  }
}

# Interface VPC Endpoints for NAT-less ECS
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.all_interface_endpoints)
  
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true  # Critical for ECR pulls to work
  
  tags = {
    Name        = "${var.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
    Environment = var.environment
    Type        = "Interface"
    Service     = each.value
  }
}

# Security group for ECS tasks with proper egress rules
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks"
  description = "Security group for ECS tasks with NAT-less egress"
  vpc_id      = aws_vpc.main.id
  
  # Egress to VPC for interface endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to VPC endpoints"
  }
  
  # Egress to S3 prefix list for ECR layer downloads
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
    description     = "HTTPS to S3 for ECR layers"
  }
  
  # Egress to DynamoDB prefix list
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.dynamodb.id]
    description     = "HTTPS to DynamoDB"
  }
  
  tags = {
    Name        = "${var.name_prefix}-ecs-tasks-sg"
    Environment = var.environment
  }
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  
  tags = {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
  }
}

# Additional security group rule: ALB -> ECS tasks
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "ALB to ECS tasks"
}

# Additional security group rule: VPC endpoints allow ECS tasks
resource "aws_security_group_rule" "vpce_from_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "ECS tasks to VPC endpoints"
}
