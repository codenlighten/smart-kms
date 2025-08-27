# Development outputs
output "signer_role_arn" { value = aws_iam_role.signer_role.arn }
output "kms_anchor_alias" { value = aws_kms_alias.anchor_alias.name }
output "kms_issue_alias"  { value = aws_kms_alias.issue_alias.name }
output "receipts_table_name" { value = aws_dynamodb_table.receipts.name }
output "artifacts_bucket" { value = var.create_artifacts_bucket ? aws_s3_bucket.artifacts[0].bucket : null }

# Production outputs
output "api_endpoint" {
  description = "API endpoint URL"
  value       = var.environment == "production" ? (var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_lb.main[0].dns_name}") : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.environment == "production" ? aws_ecs_cluster.main[0].name : null
}

output "ecr_sign_service_repository_url" {
  description = "ECR repository URL for sign service"
  value       = var.environment == "production" ? aws_ecr_repository.sign_service[0].repository_url : null
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = var.environment == "production" ? "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.environment == "production" ? aws_lb.main[0].dns_name : null
}

output "nameservers" {
  description = "Route 53 nameservers (if managing DNS)"
  value       = var.environment == "production" && var.domain_name != "" && var.manage_dns ? aws_route53_zone.main[0].name_servers : null
}
