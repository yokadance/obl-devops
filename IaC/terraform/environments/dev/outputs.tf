# # environments/dev/outputs.tf
# output "alb_dns_name" {
#   description = "ALB DNS name"
#   value       = module.alb.alb_dns_name
# }

# output "ecr_repositories" {
#   description = "ECR repository URLs"
#   value = {
#     api_gateway       = aws_ecr_repository.api_gateway.repository_url
#     product_service   = aws_ecr_repository.product_service.repository_url
#     inventory_service = aws_ecr_repository.inventory_service.repository_url
#   }
# }

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
