.PHONY: help init plan apply destroy build push deploy

ENV ?= dev
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)

help:
	@echo "Uso: make [comando] ENV=dev"
	@echo ""
	@echo "Comandos disponibles:"
	@echo "  init          - Inicializar Terraform"
	@echo "  plan          - Ver plan de ejecución"
	@echo "  apply         - Aplicar cambios"
	@echo "  destroy       - Destruir infraestructura"
	@echo "  build         - Construir imágenes Docker"
	@echo "  push          - Subir imágenes a ECR"
	@echo "  deploy        - Build + Push + Deploy"

init:
	cd environments/$(ENV) && terraform init

plan:
	cd environments/$(ENV) && terraform plan

apply:
	cd environments/$(ENV) && terraform apply

destroy:
	cd environments/$(ENV) && terraform destroy

ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

build: ecr-login
	@echo "Construyendo imágenes..."
	docker build -t $(ENV)/api-gateway:latest ../../api-gateway
	docker build -t $(ENV)/product-service:latest ../../product-service
	docker build -t $(ENV)/inventory-service:latest ../../inventory-service
	docker tag $(ENV)/api-gateway:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/api-gateway:latest
	docker tag $(ENV)/product-service:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/product-service:latest
	docker tag $(ENV)/inventory-service:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/inventory-service:latest

push: ecr-login
	@echo "Subiendo imágenes a ECR..."
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/api-gateway:latest
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/product-service:latest
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ENV)/inventory-service:latest

deploy: build push
	@echo "Desplegando servicios..."
	aws ecs update-service --cluster $(ENV)-cluster --service $(ENV)-api-gateway --force-new-deployment --region $(AWS_REGION)
	aws ecs update-service --cluster $(ENV)-cluster --service $(ENV)-product-service --force-new-deployment --region $(AWS_REGION)
	aws ecs update-service --cluster $(ENV)-cluster --service $(ENV)-inventory-service --force-new-deployment --region $(AWS_REGION)

outputs:
	cd environments/$(ENV) && terraform output