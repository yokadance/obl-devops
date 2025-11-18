# ECR Repository URLs
output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "api_gateway_ecr_url" {
  description = "API Gateway ECR repository URL"
  value       = module.ecr.api_gateway_repository_url
}

output "product_service_ecr_url" {
  description = "Product Service ECR repository URL"
  value       = module.ecr.product_service_repository_url
}

output "inventory_service_ecr_url" {
  description = "Inventory Service ECR repository URL"
  value       = module.ecr.inventory_service_repository_url
}

# ALB
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

# output "ecs_cluster_name" {
#   description = "ECS cluster name"
#   value       = module.ecs.cluster_name
# }

# output "cloudwatch_dashboard" {
#   description = "CloudWatch dashboard name"
#   value       = module.monitoring.dashboard_name
# }

# output "vpc_id" {
#   description = "VPC ID"
#   value       = module.vpc.vpc_id
# }

# output "nat_gateway_ips" {
#   description = "NAT Gateway IPs"
#   value       = module.vpc.nat_gateway_ips
# }
