terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Configuración del backend remoto en S3
  # Descomentar después de crear el bucket manualmente con:
  # aws s3api create-bucket --bucket stockwiz-terraform-state-dev --region us-east-1
  # aws s3api put-bucket-versioning --bucket stockwiz-terraform-state-dev --versioning-configuration Status=Enabled
  
  # backend "s3" {
  #   bucket         = "stockwiz-terraform-state-dev"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}