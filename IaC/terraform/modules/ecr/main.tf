# ============================================
# ECR REPOSITORIES
# ============================================

# API Gateway Repository
resource "aws_ecr_repository" "api_gateway" {
  name                 = "${var.environment}-stockwiz-api-gateway"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.environment}-api-gateway-ecr"
    Service     = "api-gateway"
    Environment = var.environment
  }
}

# Product Service Repository
resource "aws_ecr_repository" "product_service" {
  name                 = "${var.environment}-stockwiz-product-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.environment}-product-service-ecr"
    Service     = "product-service"
    Environment = var.environment
  }
}

# Inventory Service Repository
resource "aws_ecr_repository" "inventory_service" {
  name                 = "${var.environment}-stockwiz-inventory-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.environment}-inventory-service-ecr"
    Service     = "inventory-service"
    Environment = var.environment
  }
}

# ============================================
# ECR LIFECYCLE POLICIES
# ============================================

# Lifecycle policy para API Gateway
resource "aws_ecr_lifecycle_policy" "api_gateway" {
  repository = aws_ecr_repository.api_gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy para Product Service
resource "aws_ecr_lifecycle_policy" "product_service" {
  repository = aws_ecr_repository.product_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy para Inventory Service
resource "aws_ecr_lifecycle_policy" "inventory_service" {
  repository = aws_ecr_repository.inventory_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# PostgreSQL Repository
resource "aws_ecr_repository" "postgres" {
  name                 = "${var.environment}-stockwiz-postgres"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.environment}-postgres-ecr"
    Service     = "postgres"
    Environment = var.environment
  }
}

# Lifecycle policy para PostgreSQL
resource "aws_ecr_lifecycle_policy" "postgres" {
  repository = aws_ecr_repository.postgres.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}


//Description autogeneradas con cursor