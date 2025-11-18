# Quick Start - Deploy StockWiz a AWS ECS

Guía rápida para desplegar StockWiz en AWS usando Terraform y ECS.

## Pasos Rápidos

### 1. Inicializar y Desplegar Infraestructura

```bash
# Inicializar Terraform
make terraform-init ENV=dev

# Ver el plan
make terraform-plan ENV=dev

# Aplicar (crear VPC, ALB, ECR, ECS, etc.)
make terraform-apply ENV=dev
```

Esto creará:
- ✅ VPC con subnets públicas y privadas
- ✅ Application Load Balancer (ALB)
- ✅ 3 Repositorios ECR (api-gateway, product-service, inventory-service)
- ✅ ECS Cluster con Fargate
- ✅ 3 ECS Services con auto-scaling
- ✅ CloudWatch Logs

### 2. Build, Push y Deploy (Todo en Uno)

```bash
# Opción más simple - hace todo automáticamente
make deploy-all ENV=dev
```

Este comando:
1. ✅ Construye las 3 imágenes Docker
2. ✅ Las sube a ECR con tags automáticos
3. ✅ Despliega a ECS y espera a que estén estables

**Tiempo estimado**: 5-10 minutos

### 3. Verificar el Despliegue

```bash
# Obtener URL del ALB
cd IaC/terraform/environments/dev
terraform output alb_dns_name

# Probar la aplicación
curl http://<ALB-DNS>/health
curl http://<ALB-DNS>/api/products
curl http://<ALB-DNS>/api/inventory
```

## Comandos Alternativos

### Build y Push sin Deploy

```bash
# Solo subir imágenes a ECR
make ecr-build-push-all ENV=dev
```

### Solo Deploy (si las imágenes ya están en ECR)

```bash
# Redesplegar servicios con las últimas imágenes
make deploy-ecs ENV=dev
```

### Deploy de un Servicio Específico

```bash
# Solo API Gateway
make deploy-all ENV=dev SERVICE=api-gateway

# Solo Product Service
make deploy-all ENV=dev SERVICE=product-service

# Solo Inventory Service
make deploy-all ENV=dev SERVICE=inventory-service
```

## Verificación Rápida

```bash
# Ver estado de los servicios ECS
aws ecs list-services --cluster dev-cluster --region us-east-1

# Ver tareas corriendo
aws ecs list-tasks --cluster dev-cluster --region us-east-1

# Ver logs en tiempo real
aws logs tail /ecs/dev --follow
```

## Arquitectura Desplegada

```
Internet
   |
   v
Application Load Balancer (ALB)
   |
   +-- /           -> API Gateway (port 8000)
   +-- /api/products  -> Product Service (port 8001)
   +-- /api/inventory -> Inventory Service (port 8002)
   |
   v
ECS Fargate Tasks (en subnets privadas)
   - dev-api-gateway (1-4 tasks con auto-scaling)
   - dev-product-service (1-4 tasks con auto-scaling)
   - dev-inventory-service (1-4 tasks con auto-scaling)
```

## Estructura de Comandos Make

```bash
make help                          # Ver todos los comandos disponibles

# Terraform
make terraform-init ENV=dev        # Inicializar
make terraform-plan ENV=dev        # Ver plan
make terraform-apply ENV=dev       # Aplicar
make terraform-destroy ENV=dev     # Destruir

# Docker/ECR
make ecr-login ENV=dev             # Login a ECR
make ecr-build-push-all ENV=dev    # Build y push todos los servicios

# Deploy
make deploy-all ENV=dev            # Build + Push + Deploy (TODO)
make deploy-ecs ENV=dev            # Solo deploy a ECS
```

## Troubleshooting Rápido

### Error: "no basic auth credentials"
```bash
make ecr-login ENV=dev
```

### Error: "repository does not exist"
```bash
make terraform-apply ENV=dev
```

### Tareas no se inician
```bash
# Ver logs
aws logs tail /ecs/dev --follow

# Ver razón del error
aws ecs describe-services --cluster dev-cluster --services dev-api-gateway --region us-east-1
```

### Health checks fallan
```bash
# Aumentar grace period en IaC/terraform/modules/ecs/main.tf
# health_check_grace_period_seconds = 120

make terraform-apply ENV=dev
make deploy-ecs ENV=dev
```

## Costos Estimados (us-east-1)

Para el ambiente dev con 3 servicios (1 tarea cada uno):

- **Fargate Tasks**: ~$13/mes (256 CPU, 512 MB cada uno)
- **ALB**: ~$16/mes
- **NAT Gateway**: ~$32/mes
- **CloudWatch Logs**: ~$1/mes
- **ECR Storage**: ~$1/mes (primeros 50GB)

**Total estimado**: ~$63/mes

## Limpieza (Destruir Todo)

```bash
# CUIDADO: Esto destruye toda la infraestructura
make terraform-destroy ENV=dev
```

## Siguientes Pasos

1. ✅ Configurar dominio personalizado con Route53
2. ✅ Agregar RDS para PostgreSQL
3. ✅ Agregar ElastiCache para Redis
4. ✅ Configurar CI/CD con GitHub Actions
5. ✅ Implementar certificados SSL con ACM

Ver documentación completa en:
- [README_DEPLOY_ECS.md](README_DEPLOY_ECS.md) - Guía completa de deploy
- [README_DOCKER_ECR.md](README_DOCKER_ECR.md) - Guía de ECR
