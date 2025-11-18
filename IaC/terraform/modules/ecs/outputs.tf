output "cluster_id" {
  description = "ECS Cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

# Service outputs
output "api_gateway_service_name" {
  description = "API Gateway service name"
  value       = aws_ecs_service.api_gateway.name
}

output "product_service_service_name" {
  description = "Product Service service name"
  value       = aws_ecs_service.product_service.name
}

output "inventory_service_service_name" {
  description = "Inventory Service service name"
  value       = aws_ecs_service.inventory_service.name
}

# Task definition outputs
output "api_gateway_task_definition_arn" {
  description = "API Gateway task definition ARN"
  value       = aws_ecs_task_definition.api_gateway.arn
}

output "product_service_task_definition_arn" {
  description = "Product Service task definition ARN"
  value       = aws_ecs_task_definition.product_service.arn
}

output "inventory_service_task_definition_arn" {
  description = "Inventory Service task definition ARN"
  value       = aws_ecs_task_definition.inventory_service.arn
}

