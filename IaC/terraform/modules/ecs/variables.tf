variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "api_gateway_target_group_arn" {
  description = "ARN of API Gateway target group"
  type        = string
}

variable "product_service_target_group_arn" {
  description = "ARN of Product Service target group"
  type        = string
}

variable "inventory_service_target_group_arn" {
  description = "ARN of Inventory Service target group"
  type        = string
}

variable "api_gateway_ecr_url" {
  description = "ECR repository URL for API Gateway"
  type        = string
}

variable "product_service_ecr_url" {
  description = "ECR repository URL for Product Service"
  type        = string
}

variable "inventory_service_ecr_url" {
  description = "ECR repository URL for Inventory Service"
  type        = string
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MB) for the task"
  type        = number
  default     = 512
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}