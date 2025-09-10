# VPC and Networking Configuration for Production ECS Deployment

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  count = var.environment == "production" ? 1 : 0
  
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-vpc"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-igw"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Public Subnets (for ALB)
resource "aws_subnet" "public" {
  count = var.environment == "production" ? 2 : 0
  
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-public-${count.index + 1}"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
    Type        = "public"
  }
}

# Private Subnets (for ECS tasks)
resource "aws_subnet" "private" {
  count = var.environment == "production" ? 2 : 0
  
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-private-${count.index + 1}"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
    Type        = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-public-rt"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Route Table for Private Subnets (no NAT - VPC endpoints only)
resource "aws_route_table" "private" {
  count = var.environment == "production" ? 1 : 0
  
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-private-rt"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count = var.environment == "production" ? 2 : 0
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count = var.environment == "production" ? 2 : 0
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  count = var.environment == "production" ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.tenant_id}-alb-"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-alb-sg"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  count = var.environment == "production" ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.tenant_id}-ecs-"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  egress {
    description = "HTTPS for VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "HTTPS for internet access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-ecs-sg"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.environment == "production" ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.tenant_id}-vpce-"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "HTTPS from ECS tasks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name        = "${var.project_name}-${var.tenant_id}-vpce-sg"
    Project     = var.project_name
    Tenant      = var.tenant_id
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}
