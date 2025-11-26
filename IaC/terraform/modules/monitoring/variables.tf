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

variable "ecs_cluster_name" {
  description = "ECS Cluster name for alarms"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications (optional)"
  type        = string
  default     = ""
}
