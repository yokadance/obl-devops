.PHONY: help terraform-init terraform-plan terraform-apply terraform-destroy docker-build docker-push docker-build-push ecr-login ecr-build-push-all ecr-build-push-service deploy-ecs deploy-all

# Variables
ENV ?= dev
AWS_REGION ?= us-east-1
TAG ?= latest
TERRAFORM_DIR = IaC/terraform/environments/$(ENV)
APP_DIR = app/StockWiz

help: ## Mostrar esta ayuda
	@echo "Comandos disponibles:"
	@echo ""
	@echo "Terraform:"
	@echo "  make terraform-init ENV=dev     - Inicializar Terraform para un entorno"
	@echo "  make terraform-plan ENV=dev      - Ver plan de Terraform"
	@echo "  make terraform-apply ENV=dev    - Aplicar cambios de Terraform"
	@echo "  make terraform-destroy ENV=dev  - Destruir infraestructura"
	@echo ""
	@echo "Docker/ECR:"
	@echo "  make ecr-login ENV=dev                        - Hacer login a ECR"
	@echo "  make docker-build ENV=dev                     - Construir imágenes Docker localmente"
	@echo "  make docker-push ENV=dev TAG=latest           - Pushear imágenes a ECR"
	@echo "  make docker-build-push ENV=dev TAG=latest     - Build y push en un solo comando"
	@echo "  make ecr-build-push-all ENV=dev               - Build y push todos los servicios (recomendado)"
	@echo "  make ecr-build-push-service ENV=dev SERVICE=api-gateway - Build y push un servicio específico"
	@echo ""
	@echo "Deploy a ECS:"
	@echo "  make deploy-ecs ENV=dev SERVICE=all           - Desplegar servicios a ECS"
	@echo "  make deploy-all ENV=dev                       - Build, push y deploy completo (recomendado)"
	@echo ""
	@echo "Ejemplos:"
	@echo "  make terraform-apply ENV=dev"
	@echo "  make deploy-all ENV=dev                       # Deploy completo"
	@echo "  make ecr-build-push-all ENV=dev               # Solo build y push"
	@echo "  make deploy-ecs ENV=dev SERVICE=api-gateway   # Deploy un servicio"

# ============================================
# TERRAFORM
# ============================================

terraform-init: ## Inicializar Terraform
	@echo "Inicializando Terraform para entorno: $(ENV)"
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan: ## Ver plan de Terraform
	@echo "Generando plan para entorno: $(ENV)"
	cd $(TERRAFORM_DIR) && terraform plan

terraform-apply: ## Aplicar cambios de Terraform
	@echo "Aplicando cambios para entorno: $(ENV)"
	cd $(TERRAFORM_DIR) && terraform apply

terraform-destroy: ## Destruir infraestructura
	@echo "⚠️  Destruyendo infraestructura para entorno: $(ENV)"
	@read -p "¿Estás seguro? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TERRAFORM_DIR) && terraform destroy; \
	fi

terraform-output: ## Mostrar outputs de Terraform
	@echo "Outputs para entorno: $(ENV)"
	cd $(TERRAFORM_DIR) && terraform output

# ============================================
# DOCKER / ECR
# ============================================

ecr-login: ## Hacer login a ECR
	@echo "Haciendo login a ECR..."
	@AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text); \
	aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $$AWS_ACCOUNT_ID.dkr.ecr.$(AWS_REGION).amazonaws.com

docker-build: ## Construir imágenes Docker localmente
	@echo "Construyendo imágenes Docker..."
	@echo "API Gateway..."
	docker build -t api-gateway:$(TAG) -f $(APP_DIR)/api-gateway/Dockerfile $(APP_DIR)/api-gateway
	@echo "Product Service..."
	docker build -t product-service:$(TAG) -f $(APP_DIR)/product-service/Dockerfile $(APP_DIR)/product-service
	@echo "Inventory Service..."
	docker build -t inventory-service:$(TAG) -f $(APP_DIR)/inventory-service/Dockerfile $(APP_DIR)/inventory-service
	@echo "✓ Imágenes construidas exitosamente"

docker-build-push: ## Build y push de todos los servicios usando el script principal
	@echo "Build y push de todos los servicios para entorno: $(ENV)"
	@./scripts/build-and-push-ecr.sh $(ENV) all

ecr-build-push-all: ## Build y push todos los servicios a ECR (script automatizado)
	@echo "Build y push de todos los servicios para entorno: $(ENV)"
	@./scripts/build-and-push-ecr.sh $(ENV) all

ecr-build-push-service: ## Build y push un servicio específico a ECR (SERVICE=api-gateway|product-service|inventory-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: Debes especificar SERVICE=<nombre>"; \
		echo "Servicios válidos: api-gateway, product-service, inventory-service"; \
		exit 1; \
	fi
	@echo "Build y push de $(SERVICE) para entorno: $(ENV)"
	@./scripts/build-and-push-ecr.sh $(ENV) $(SERVICE)

# ============================================
# DEPLOY A ECS
# ============================================

deploy-ecs: ## Desplegar servicios a ECS (SERVICE=all|api-gateway|product-service|inventory-service)
	@if [ -z "$(SERVICE)" ]; then \
		echo "Desplegando todos los servicios a ECS para entorno: $(ENV)"; \
		./scripts/deploy-to-ecs.sh $(ENV) all; \
	else \
		echo "Desplegando $(SERVICE) a ECS para entorno: $(ENV)"; \
		./scripts/deploy-to-ecs.sh $(ENV) $(SERVICE); \
	fi

deploy-all: ## Build, push y deploy completo (SERVICE=all por defecto)
	@echo "🚀 Iniciando deploy completo para entorno: $(ENV)"
	@./scripts/build-push-deploy.sh $(ENV) $(or $(SERVICE),all)

# ============================================
# UTILIDADES
# ============================================

get-ecr-urls: ## Obtener URLs de repositorios ECR
	@echo "Obteniendo URLs de ECR para entorno: $(ENV)"
	@cd $(TERRAFORM_DIR) && terraform output -json ecr_repositories | jq -r 'to_entries[] | "\(.key): \(.value)"'

validate-terraform: ## Validar configuración de Terraform
	@echo "Validando Terraform para entorno: $(ENV)"
	cd $(TERRAFORM_DIR) && terraform validate

format-terraform: ## Formatear archivos Terraform
	@echo "Formateando archivos Terraform..."
	find IaC/terraform -name "*.tf" -exec terraform fmt {} \;
