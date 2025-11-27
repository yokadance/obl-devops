output "dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "lambda_function_name" {
  description = "Health Checker Lambda function name"
  value       = aws_lambda_function.health_checker.function_name
}

output "lambda_function_arn" {
  description = "Health Checker Lambda function ARN"
  value       = aws_lambda_function.health_checker.arn
}

output "alarms" {
  description = "CloudWatch Alarms"
  value = {
    http_health  = aws_cloudwatch_metric_alarm.health_check_http_alarm.alarm_name
    https_health = aws_cloudwatch_metric_alarm.health_check_https_alarm.alarm_name
    cpu_high     = aws_cloudwatch_metric_alarm.ecs_cpu_high.alarm_name
    memory_high  = aws_cloudwatch_metric_alarm.ecs_memory_high.alarm_name
    alb_5xx      = aws_cloudwatch_metric_alarm.alb_5xx_errors.alarm_name
  }
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS Topic name for alerts"
  value       = aws_sns_topic.alerts.name
}
