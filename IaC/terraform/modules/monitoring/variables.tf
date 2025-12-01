variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "alb_dns_name" {
  description = "ALB DNS name to monitor"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics (format: app/name/id)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS Cluster name for alarms"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name for CloudWatch metrics"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for alert notifications (optional)"
  type        = string
  default     = ""
}
