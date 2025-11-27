terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Descomentar después de crear el bucket S3 manualmente
  # backend "s3" {
  #   bucket         = "stockwiz-terraform-state-dev"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "StockWiz"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Team        = "DevOps"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment            = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.vpc.alb_security_group_id
}

# ECS Module (Solo cluster vacío, sin servicios por ahora)
module "ecs" {
  source = "../../modules/ecs"

  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  ecs_tasks_security_group_id = module.vpc.ecs_tasks_security_group_id

  depends_on = [module.alb]
}