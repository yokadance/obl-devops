output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "api_gateway_target_group_arn" {
  description = "ARN of API Gateway target group"
  value       = aws_lb_target_group.api_gateway.arn
}

output "product_service_target_group_arn" {
  description = "ARN of Product Service target group"
  value       = aws_lb_target_group.product_service.arn
}

output "inventory_service_target_group_arn" {
  description = "ARN of Inventory Service target group"
  value       = aws_lb_target_group.inventory_service.arn
}

output "http_listener_arn" {
  description = "ARN of HTTP listener"
  value       = aws_lb_listener.http.arn
}


//Description autogeneradas con cursor