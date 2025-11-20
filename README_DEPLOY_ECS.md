# Guía de Despliegue Automático a ECS

Esta guía explica cómo desplegar automáticamente las imágenes Docker desde ECR a ECS.

## Arquitectura del Despliegue

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Docker Build  │ --> │   Push to ECR   │ --> │  Deploy to ECS  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        v                       v                       v
   Dockerfiles            ECR Repositories        ECS Services
   - api-gateway          - dev-api-gateway       - dev-api-gateway
   - product-service      - dev-product-service   - dev-product-service
   - inventory-service    - dev-inventory-service - dev-inventory-service
```

## Configuración Actual de ECS

### Task Definitions
- **CPU**: 256 units (0.25 vCPU)
- **Memory**: 512 MB
- **Network Mode**: awsvpc
- **Launch Type**: Fargate

### Services
- **Desired Count**: 1 tarea por servicio
- **Deployment**: Rolling update
  - Maximum: 200% (permite 2 tareas durante deploy)
  - Minimum: 100% (mantiene 1 tarea siempre)
- **Health Check Grace Period**: 60 segundos

### Auto Scaling
Cada servicio tiene configurado auto-scaling basado en:
- **CPU Utilization**: Scale out cuando CPU > 70%, min=1, max=4
- **Memory Utilization**: Scale out cuando Memory > 80%, min=1, max=4

## Prerrequisitos

1. **Infraestructura desplegada**:
   ```bash
   cd IaC/terraform/environments/dev
   terraform init
   terraform apply
   ```

2. **Imágenes en ECR**:
   Las imágenes deben estar pusheadas a ECR (ver [README_DOCKER_ECR.md](README_DOCKER_ECR.md))

3. **AWS CLI configurado** con credenciales válidas

## Métodos de Despliegue

### Método 1: Deploy Completo (Recomendado)

Este método ejecuta todo el proceso: build, push y deploy.

```bash
# Desplegar todos los servicios
make deploy-all ENV=dev

# Desplegar un servicio específico
make deploy-all ENV=dev SERVICE=api-gateway
```

**¿Qué hace?**
1. Construye las imágenes Docker
2. Las pushea a ECR con tags automáticos
3. Fuerza el redespliegue en ECS
4. Espera a que los servicios se estabilicen

### Método 2: Solo Deploy a ECS

Si ya tienes las imágenes en ECR y solo quieres redesplegar:

```bash
# Redesplegar todos los servicios
make deploy-ecs ENV=dev

# Redesplegar un servicio específico
make deploy-ecs ENV=dev SERVICE=product-service
```

### Método 3: Usando Scripts Directamente

```bash
# Deploy completo
./scripts/build-push-deploy.sh dev all

# Solo deploy a ECS
./scripts/deploy-to-ecs.sh dev api-gateway

# Solo build y push
./scripts/build-and-push-ecr.sh dev inventory-service
```

## Proceso de Despliegue

### ¿Qué sucede durante un deploy?

1. **Force New Deployment**: ECS crea nuevas tareas con la última versión de la imagen
2. **Health Checks**: Las nuevas tareas deben pasar los health checks
3. **ALB Target Registration**: Las tareas se registran en el target group del ALB
4. **Rolling Update**:
   - Se crean nuevas tareas (hasta 200% = 2 tareas)
   - Una vez saludables, se eliminan las tareas viejas
   - Siempre hay al menos 1 tarea corriendo (100%)
5. **Stabilization**: El servicio se marca como estable

### Timeouts y Tiempos de Espera

- **Health Check Grace Period**: 60 segundos
- **Health Check Interval**: 30 segundos
- **Start Period**: 40 segundos
- **Tiempo total estimado**: 2-5 minutos por servicio

## Verificación del Despliegue

### Ver estado de los servicios

```bash
# Via AWS CLI
aws ecs list-services --cluster dev-cluster --region us-east-1

# Ver detalles de un servicio
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-api-gateway \
  --region us-east-1

# Ver tareas corriendo
aws ecs list-tasks --cluster dev-cluster --region us-east-1
```

### Ver logs de los contenedores

```bash
# Los logs están en CloudWatch Logs
# Grupo: /ecs/dev
# Streams:
#   - api-gateway/...
#   - product-service/...
#   - inventory-service/...

# Ver logs en tiempo real
aws logs tail /ecs/dev --follow --filter-pattern "api-gateway"
```

### Verificar en el ALB

```bash
# Obtener DNS del ALB
cd IaC/terraform/environments/dev
terraform output alb_dns_name

# Probar endpoints
curl http://<ALB-DNS>/health
curl http://<ALB-DNS>/api/products
curl http://<ALB-DNS>/api/inventory
```

## Rollback

Si necesitas hacer rollback a una versión anterior:

### Opción 1: Deploy de una imagen anterior

```bash
# 1. Listar imágenes disponibles en ECR
aws ecr describe-images \
  --repository-name dev-stockwiz-api-gateway \
  --region us-east-1

# 2. Actualizar la task definition para usar una imagen específica
# Editar: IaC/terraform/modules/ecs/main.tf
# Cambiar: image = "${var._ecr_url}:latest"
# Por: image = "${var.api_gateway_ecr_url}:20251118-143025-a1b2c3d"

# 3. Aplicar cambios
cd IaC/terraform/environments/dev
terraform apply

# 4. Forzar redespliegue
make deploy-ecs ENV=dev SERVICE=api-gateway
```

### Opción 2: Rollback via AWS Console

1. Ve a ECS > Clusters > dev-cluster
2. Selecciona el servicio
3. Click en "Update service"
4. Selecciona una revisión anterior de la task definition
5. Click "Update"

## Troubleshooting

### Las tareas no se inician

**Problema**: Las tareas van a estado STOPPED

**Solución**:
```bash
# Ver razón del error
aws ecs describe-tasks \
  --cluster dev-cluster \
  --tasks <TASK-ARN> \
  --region us-east-1 \
  --query 'tasks[0].stoppedReason'

# Causas comunes:
# 1. Imagen no existe en ECR -> Verificar ECR
# 2. Error de permisos IAM -> Verificar labRole
# 3. No hay IPs disponibles -> Verificar subnets
```

### Health checks fallan

**Problema**: Las tareas no pasan health checks del ALB

**Solución**:
```bash
# 1. Verificar logs del contenedor
aws logs tail /ecs/dev --follow --filter-pattern "api-gateway"

# 2. Verificar que el endpoint /health responde
# Conectarse a la tarea via Session Manager o ver logs

# 3. Ajustar health check grace period si es necesario
# Editar: IaC/terraform/modules/ecs/main.tf
# health_check_grace_period_seconds = 120  # Aumentar a 2 minutos
```

### Servicio no se estabiliza

**Problema**: El comando `aws ecs wait services-stable` timeout

**Solución**:
```bash
# Verificar eventos del servicio
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-api-gateway \
  --region us-east-1 \
  --query 'services[0].events[:10]'

# Ver tareas fallidas
aws ecs list-tasks \
  --cluster dev-cluster \
  --desired-status STOPPED \
  --region us-east-1
```

### No hay conectividad desde el ALB a las tareas

**Problema**: ALB marca las tareas como unhealthy

**Solución**:
```bash
# 1. Verificar security groups
# - ECS tasks deben permitir tráfico desde ALB
# - ALB debe permitir tráfico desde internet

# 2. Verificar que las tareas están en subnets privadas
cd IaC/terraform/environments/dev
terraform output | grep subnet

# 3. Verificar que hay NAT Gateway para internet outbound
terraform output | grep nat
```

## Variables de Entorno

Las task definitions incluyen variables de entorno predefinidas:

### API Gateway
- `PRODUCT_SERVICE_URL`: http://localhost:8001
- `INVENTORY_SERVICE_URL`: http://localhost:8002
- `REDIS_URL`: localhost:6379

### Product Service
- `DATABASE_URL`: postgresql://admin:admin123@localhost:5432/microservices_db
- `REDIS_URL`: redis://localhost:6379

### Inventory Service
- `DATABASE_URL`: postgres://admin:admin123@localhost:5432/microservices_db?sslmode=disable
- `REDIS_URL`: localhost:6379


## Comandos Útiles

```bash
# Ver todos los comandos disponibles
make help

# Aplicar infraestructura
make terraform-apply ENV=dev

# Build y push imágenes
make ecr-build-push-all ENV=dev

# Deploy completo
make deploy-all ENV=dev

# Solo redesplegar
make deploy-ecs ENV=dev SERVICE=all

# Ver URLs de ECR
make get-ecr-urls ENV=dev

# Ver DNS del ALB
cd IaC/terraform/environments/dev && terraform output alb_dns_name
```

