data "aws_caller_identity" "current" {}

# ECS Task Role (application permissions)
resource "aws_iam_role" "signer_role" {
  name = "${local.name_prefix}-signer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Alias for ECS Task Role (for compatibility)
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# ECS Execution Role (for pulling images, logging, etc.)
resource "aws_iam_role" "ecs_execution_role" {
  count = var.environment == "production" ? 1 : 0
  
  name = "${local.name_prefix}-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Application permissions (KMS, DynamoDB)
resource "aws_iam_policy" "signer_policy" {
  name = "${local.name_prefix}-signer-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["kms:Sign","kms:GetPublicKey","kms:DescribeKey"],
        Resource = [
          aws_kms_key.anchor.arn,
          aws_kms_key.issue.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem"],
        Resource = aws_dynamodb_table.receipts.arn
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

# ECS Execution permissions (ECR, CloudWatch Logs)
resource "aws_iam_policy" "ecs_execution_policy" {
  count = var.environment == "production" ? 1 : 0
  
  name = "${local.name_prefix}-ecs-execution-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.signer_role.name
  policy_arn = aws_iam_policy.signer_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.signer_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  count = var.environment == "production" ? 1 : 0
  
  role       = aws_iam_role.ecs_execution_role[0].name
  policy_arn = aws_iam_policy.ecs_execution_policy[0].arn
}
