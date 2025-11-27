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

output "stockwiz_service_name" {
  description = "StockWiz unified service name"
  value       = aws_ecs_service.stockwiz.name
}

output "stockwiz_task_definition_arn" {
  description = "StockWiz task definition ARN"
  value       = aws_ecs_task_definition.stockwiz.arn
}

//Description autogeneradas con cursor