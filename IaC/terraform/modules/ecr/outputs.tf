output "api_gateway_repository_url" {
  description = "URL of the API Gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.repository_url
}

output "api_gateway_repository_arn" {
  description = "ARN of the API Gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.arn
}

output "product_service_repository_url" {
  description = "URL of the Product Service ECR repository"
  value       = aws_ecr_repository.product_service.repository_url
}

output "product_service_repository_arn" {
  description = "ARN of the Product Service ECR repository"
  value       = aws_ecr_repository.product_service.arn
}

output "inventory_service_repository_url" {
  description = "URL of the Inventory Service ECR repository"
  value       = aws_ecr_repository.inventory_service.repository_url
}

output "inventory_service_repository_arn" {
  description = "ARN of the Inventory Service ECR repository"
  value       = aws_ecr_repository.inventory_service.arn
}

output "postgres_repository_url" {
  description = "URL of the PostgreSQL ECR repository"
  value       = aws_ecr_repository.postgres.repository_url
}

output "postgres_repository_arn" {
  description = "ARN of the PostgreSQL ECR repository"
  value       = aws_ecr_repository.postgres.arn
}

output "repository_urls" {
  description = "Map of all ECR repository URLs"
  value = {
    api_gateway       = aws_ecr_repository.api_gateway.repository_url
    product_service   = aws_ecr_repository.product_service.repository_url
    inventory_service = aws_ecr_repository.inventory_service.repository_url
    postgres          = aws_ecr_repository.postgres.repository_url
  }
}


//Description autogeneradas con cursor