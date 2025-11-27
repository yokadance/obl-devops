.PHONY: help setup-backend terraform-init terraform-plan terraform-apply terraform-destroy docker-build docker-push docker-build-push ecr-login ecr-build-push-all ecr-build-push-service deploy-ecs deploy-all report view-report setup-and-deploy

# Variables
ENV ?= dev
AWS_REGION ?= us-east-1
TAG ?= latest
TERRAFORM_DIR = IaC/terraform/environments/$(ENV)
APP_DIR = app/StockWiz

help: ## Mostrar esta ayuda
	@echo "Comandos disponibles:"
	@echo ""
	@echo "Setup Inicial:"
	@echo "  make setup-backend              - Configurar backend S3 (ejecutar UNA VEZ al inicio)"
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
	@echo "Reportes:"
	@echo "  make report ENV=dev                           - Generar reporte HTML y abrir en navegador"
	@echo "  make view-report ENV=dev                      - Abrir reporte existente en navegador"
	@echo ""
	@echo "Flujo Completo:"
	@echo "  make setup-and-deploy ENV=dev                 - Init + Apply + Build + Push + Deploy + Reporte"
	@echo ""
	@echo "Ejemplos:"
	@echo "  make setup-backend                            # Primera vez: configurar S3"
	@echo "  make setup-and-deploy ENV=dev                 # Despliegue completo desde cero"
	@echo "  make terraform-apply ENV=dev                  # Solo infraestructura"
	@echo "  make deploy-all ENV=dev                       # Deploy completo (asume infra existente)"
	@echo "  make ecr-build-push-all ENV=dev               # Solo build y push"
	@echo "  make deploy-ecs ENV=dev SERVICE=api-gateway   # Deploy un servicio"
	@echo "  make report ENV=dev                           # Ver estado del deployment"

# ============================================
# SETUP INICIAL
# ============================================

setup-backend: ## Configurar backend S3 con tu AWS Account ID (ejecutar UNA VEZ)
	@echo "⚙️  Configurando backend S3 para Terraform..."
	@./scripts/setup-terraform-backend.sh

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

setup-and-deploy: ## Flujo completo: Init + Apply infra + Build + Push + Deploy + Reporte
	@echo "🚀 Iniciando setup y deploy completo para entorno: $(ENV)"
	@echo ""
	@echo "📋 Pasos a ejecutar:"
	@echo "  1. Terraform Init"
	@echo "  2. Terraform Apply (infraestructura)"
	@echo "  3. Build imágenes Docker"
	@echo "  4. Push a ECR"
	@echo "  5. Deploy a ECS"
	@echo "  6. Generar reporte HTML"
	@echo ""
	@read -p "¿Continuar? [Y/n] " -n 1 -r; \
	echo; \
	if [[ ! $$REPLY =~ ^[Nn]$$ ]]; then \
		echo ""; \
		echo "📦 [1/6] Inicializando Terraform..."; \
		$(MAKE) terraform-init ENV=$(ENV) || exit 1; \
		echo ""; \
		echo "🏗️  [2/6] Aplicando infraestructura..."; \
		$(MAKE) terraform-apply ENV=$(ENV) || exit 1; \
		echo ""; \
		echo "⏳ Esperando 10 segundos para que la infraestructura esté lista..."; \
		sleep 10; \
		echo ""; \
		echo "🐳 [3-5/6] Build, Push y Deploy de servicios..."; \
		$(MAKE) deploy-all ENV=$(ENV) || exit 1; \
		echo ""; \
		echo "✅ Setup y deploy completado exitosamente!"; \
	else \
		echo "Operación cancelada."; \
		exit 1; \
	fi

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

# ============================================
# REPORTES
# ============================================

report: ## Generar reporte HTML del deployment y abrirlo en el navegador
	@echo "📊 Generando reporte de deployment para entorno: $(ENV)"
	@./scripts/generate-deployment-report.sh $(ENV)

view-report: ## Abrir reporte HTML existente en el navegador
	@REPORT_FILE="deployment-report-$(ENV).html"; \
	if [ -f "$$REPORT_FILE" ]; then \
		echo "📄 Abriendo reporte: $$REPORT_FILE"; \
		if [[ "$$OSTYPE" == "darwin"* ]]; then \
			open "$$REPORT_FILE"; \
		elif [[ "$$OSTYPE" == "linux-gnu"* ]]; then \
			xdg-open "$$REPORT_FILE" 2>/dev/null || sensible-browser "$$REPORT_FILE" 2>/dev/null; \
		else \
			echo "Por favor abre manualmente: $$REPORT_FILE"; \
		fi; \
	else \
		echo "❌ Error: No existe el reporte para $(ENV)"; \
		echo "Ejecuta: make report ENV=$(ENV)"; \
		exit 1; \
	fi
