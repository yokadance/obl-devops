terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #Guardamos el tfstate de forma segura multiusuario y recuperable

  backend "s3" {
    bucket  = "stockwiz-terraform-state-493930199663"
    key     = "stage/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "StockWiz"
      Environment = "stage"
      ManagedBy   = "Terraform"
      Team        = "DevOps"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.vpc.alb_security_group_id
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"

  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  ecs_tasks_security_group_id = module.vpc.ecs_tasks_security_group_id

  # Target Groups del ALB
  api_gateway_target_group_arn       = module.alb.api_gateway_target_group_arn
  product_service_target_group_arn   = module.alb.product_service_target_group_arn
  inventory_service_target_group_arn = module.alb.inventory_service_target_group_arn

  # ECR Repository URLs
  api_gateway_ecr_url       = module.ecr.api_gateway_repository_url
  product_service_ecr_url   = module.ecr.product_service_repository_url
  inventory_service_ecr_url = module.ecr.inventory_service_repository_url
  postgres_ecr_url          = module.ecr.postgres_repository_url

  # Configuración de las tareas
  desired_count = var.ecs_desired_count
  cpu           = var.ecs_task_cpu
  memory        = var.ecs_task_memory


  # ALB DNS para comunicacion entre servicios
  alb_dns_name = module.alb.alb_dns_name

  depends_on = [module.alb, module.ecr]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  environment       = var.environment
  aws_region        = var.aws_region
  alb_dns_name      = module.alb.alb_dns_name
  alb_arn_suffix    = module.alb.alb_arn_suffix
  ecs_cluster_name  = module.ecs.cluster_name

  depends_on = [module.alb, module.ecs]
}
