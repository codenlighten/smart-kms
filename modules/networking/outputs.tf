output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint names to their IDs"
  value = merge(
    {
      s3       = aws_vpc_endpoint.s3.id
      dynamodb = aws_vpc_endpoint.dynamodb.id
    },
    {
      for k, v in aws_vpc_endpoint.interface : k => v.id
    }
  )
}

output "availability_zones" {
  description = "Availability zones used"
  value       = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs))
}
