# ============================================
# Monitoring Module
# ============================================
# Este módulo implementa:
# - Lambda para health checks
# - CloudWatch Dashboard
# - CloudWatch Alarms
# - Métricas custom

# ============================================
# Lambda Function para Health Checks
# ============================================

# Crear el código de la Lambda
data "archive_file" "health_checker_lambda" {
  type        = "zip"
  output_path = "${path.module}/health_checker.zip"

  source {
    content  = file("${path.module}/lambda/health_checker.py")
    filename = "health_checker.py"
  }
}

# Usar LabRole existente (para AWS Academy)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Lambda Function
resource "aws_lambda_function" "health_checker" {
  filename         = data.archive_file.health_checker_lambda.output_path
  function_name    = "${var.environment}-stockwiz-health-checker"
  role            = data.aws_iam_role.lab_role.arn
  handler         = "health_checker.lambda_handler"
  source_code_hash = data.archive_file.health_checker_lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      ALB_DNS_NAME = var.alb_dns_name
      ENVIRONMENT  = var.environment
    }
  }

  tags = {
    Name = "${var.environment}-health-checker"
  }
}

# CloudWatch Log Group para Lambda
# Nota: Lambda crea el log group automaticamente, pero no controla la retencion
# Si quieres controlar la retencion, descomenta este bloque e importa el recurso existente
# resource "aws_cloudwatch_log_group" "health_checker_logs" {
#   name              = "/aws/lambda/${aws_lambda_function.health_checker.function_name}"
#   retention_in_days = 7
#
#   tags = {
#     Name = "${var.environment}-health-checker-logs"
#   }
# }

# EventBridge Rule para ejecutar Lambda cada 5 minutos
resource "aws_cloudwatch_event_rule" "health_checker_schedule" {
  name                = "${var.environment}-health-checker-schedule"
  description         = "Ejecuta health checker cada 5 minutos"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "${var.environment}-health-checker-schedule"
  }
}

# Permiso para que EventBridge invoque Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.health_checker_schedule.arn
}

# Target para EventBridge
resource "aws_cloudwatch_event_target" "health_checker_target" {
  rule      = aws_cloudwatch_event_rule.health_checker_schedule.name
  target_id = "HealthCheckerLambda"
  arn       = aws_lambda_function.health_checker.arn
}

# ============================================
# CloudWatch Dashboard
# ============================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-stockwiz-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Health Status Widget
      {
        type = "metric"
        properties = {
          metrics = [
            ["StockWiz/${var.environment}", "HealthCheck-HTTP", "Environment", var.environment, "Port", "80", { stat = "Average", label = "HTTP Health" }],
            [".", "HealthCheck-HTTPS", ".", ".", ".", "443", { stat = "Average", label = "HTTPS Health" }],
            [".", "HealthCheck-APIGateway", ".", ".", ".", "80", { stat = "Average", label = "API Gateway Health" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Health Checks Status"
          yAxis = {
            left = {
              min = 0
              max = 1
            }
          }
        }
      },
      # Response Time Widget
      {
        type = "metric"
        properties = {
          metrics = [
            ["StockWiz/${var.environment}", "ResponseTime-HTTP", "Environment", var.environment, "Port", "80", { stat = "Average", label = "HTTP Response Time" }],
            [".", "ResponseTime-APIGateway", ".", ".", ".", ".", { stat = "Average", label = "API Gateway Response Time" }],
            [".", "ResponseTime-Products", ".", ".", ".", ".", { stat = "Average", label = "Products Response Time" }],
            [".", "ResponseTime-Inventory", ".", ".", ".", ".", { stat = "Average", label = "Inventory Response Time" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Response Times (ms)"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # ECS CPU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "CPU Usage" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # ECS Memory Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average", label = "Memory Usage" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Memory Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # ALB Request Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Total Requests" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # ALB Target Response Time
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Target Response Time" }],
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Target Response Time"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # ALB HTTP Codes
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "2XX Success" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4XX Client Error" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5XX Server Error" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "HTTP Response Codes"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # Lambda Invocations
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.environment}-stockwiz-health-checker", { stat = "Sum", label = "Health Checker Invocations" }],
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Health Checker Lambda Invocations"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
}

# ============================================
# SNS Topic para notificaciones
# ============================================

resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-stockwiz-alerts"

  tags = {
    Name = "${var.environment}-stockwiz-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================
# CloudWatch Alarms
# ============================================

# Alarm para Health Check HTTP
resource "aws_cloudwatch_metric_alarm" "health_check_http_alarm" {
  alarm_name          = "${var.environment}-health-check-http-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheck-HTTP"
  namespace           = "StockWiz/${var.environment}"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "HTTP health check failed"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.environment}-health-check-http-alarm"
  }
}

# Alarm para Health Check HTTPS
resource "aws_cloudwatch_metric_alarm" "health_check_https_alarm" {
  alarm_name          = "${var.environment}-health-check-https-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheck-HTTPS"
  namespace           = "StockWiz/${var.environment}"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "HTTPS health check failed"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.environment}-health-check-https-alarm"
  }
}

# Alarm para ECS CPU Alto
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.environment}-ecs-cpu-high"
  }
}

# Alarm para ECS Memory Alto
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS Memory utilization is above 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.environment}-ecs-memory-high"
  }
}

# Alarm para errores 5XX en ALB
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning too many 5XX errors"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.environment}-alb-5xx-errors"
  }
}
