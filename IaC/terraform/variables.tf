variable "environment" {
  description = "Environment name (dev, stage, prod). Se especifica en terraform.tfvars de cada entorno o con -var='environment=dev'"
  type        = string
  default     = "dev" # Default para el archivo backend.tf en la raíz. En entornos específicos se sobrescribe con terraform.tfvars
}

