# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-ecs-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.environment}-ecs-logs"
  }
}

data "aws_iam_role" "lab" {
  name = "labRole"
}
data "aws_region" "current" {}

# ============================================
# UNIFIED TASK DEFINITION - All Services in One Task
# ============================================

resource "aws_ecs_task_definition" "stockwiz" {
  family                   = "${var.environment}-stockwiz"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"  # 2 vCPU para 5 contenedores (PostgreSQL, Redis, 3 services)
  memory                   = "4096"  # 4GB para 5 contenedores
  execution_role_arn       = data.aws_iam_role.lab.arn
  task_role_arn            = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    # PostgreSQL Container
    {
      name      = "postgres"
      image     = "${var.postgres_ecr_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "POSTGRES_USER"
          value = "admin"
        },
        {
          name  = "POSTGRES_PASSWORD"
          value = "admin123"
        },
        {
          name  = "POSTGRES_DB"
          value = "microservices_db"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "postgres"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U admin -d microservices_db || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 60
      }
    },
    # Redis Container
    {
      name      = "redis"
      image     = "redis:7-alpine"
      essential = true

      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
          protocol      = "tcp"
        }
      ]

      command = ["redis-server", "--appendonly", "yes"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "redis"
        }
      }

      healthCheck = {
        command     = ["CMD", "redis-cli", "ping"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }
    },
    # API Gateway Container
    {
      name      = "api-gateway"
      image     = "${var.api_gateway_ecr_url}:latest"
      essential = true

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PRODUCT_SERVICE_URL"
          value = "http://localhost:8001"
        },
        {
          name  = "INVENTORY_SERVICE_URL"
          value = "http://localhost:8002"
        },
        {
          name  = "REDIS_URL"
          value = "localhost:6379"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api-gateway"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    },
    # Product Service Container
    {
      name      = "product-service"
      image     = "${var.product_service_ecr_url}:latest"
      essential = true

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]

      portMappings = [
        {
          containerPort = 8001
          hostPort      = 8001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgresql://admin:admin123@localhost:5432/microservices_db"
        },
        {
          name  = "REDIS_URL"
          value = "redis://localhost:6379"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "product-service"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8001/health')\" || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    },
    # Inventory Service Container
    {
      name      = "inventory-service"
      image     = "${var.inventory_service_ecr_url}:latest"
      essential = true

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]

      portMappings = [
        {
          containerPort = 8002
          hostPort      = 8002
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://admin:admin123@localhost:5432/microservices_db?sslmode=disable"
        },
        {
          name  = "REDIS_URL"
          value = "localhost:6379"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "inventory-service"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8002/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.environment}-stockwiz-task"
    Service = "stockwiz"
  }
}

# ============================================
# ECS SERVICE - Single Service for All Containers
# ============================================

resource "aws_ecs_service" "stockwiz" {
  name            = "${var.environment}-stockwiz"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.stockwiz.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  # Load balancer for API Gateway (main entry point)
  load_balancer {
    target_group_arn = var.api_gateway_target_group_arn
    container_name   = "api-gateway"
    container_port   = 8000
  }

  # Load balancer for Product Service (direct access)
  load_balancer {
    target_group_arn = var.product_service_target_group_arn
    container_name   = "product-service"
    container_port   = 8001
  }

  # Load balancer for Inventory Service (direct access)
  load_balancer {
    target_group_arn = var.inventory_service_target_group_arn
    container_name   = "inventory-service"
    container_port   = 8002
  }

  health_check_grace_period_seconds = 120

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = {
    Name    = "${var.environment}-stockwiz-service"
    Service = "stockwiz"
  }
}

# ============================================
# AUTO SCALING
# ============================================

resource "aws_appautoscaling_target" "stockwiz" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.stockwiz.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "stockwiz_cpu" {
  name               = "${var.environment}-stockwiz-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.stockwiz.resource_id
  scalable_dimension = aws_appautoscaling_target.stockwiz.scalable_dimension
  service_namespace  = aws_appautoscaling_target.stockwiz.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "stockwiz_memory" {
  name               = "${var.environment}-stockwiz-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.stockwiz.resource_id
  scalable_dimension = aws_appautoscaling_target.stockwiz.scalable_dimension
  service_namespace  = aws_appautoscaling_target.stockwiz.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
