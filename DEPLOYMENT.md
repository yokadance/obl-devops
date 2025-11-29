# Deployment Guide - StockWiz

Guía completa para desplegar StockWiz en AWS usando Terraform, ECR y ECS.

---

## 📋 Tabla de Contenidos

- [Quick Start](#-quick-start)
- [Prerequisitos](#-prerequisitos)
- [Setup Inicial del Backend S3](#-setup-inicial-del-backend-s3)
- [Deployment Completo](#-deployment-completo)
- [Build y Push de Imágenes Docker](#-build-y-push-de-imágenes-docker)
- [Deploy a ECS](#-deploy-a-ecs)
- [Verificación del Deployment](#-verificación-del-deployment)
- [Rollback](#-rollback)
- [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### Comando TODO-EN-UNO para desplegar desde cero

```bash
# 1. Setup del backend S3 (solo primera vez)
make setup-backend

# 2. Deploy completo
make setup-and-deploy ENV=dev
```

Este comando ejecuta automáticamente:
1. ✅ Terraform Init - Inicializa Terraform
2. ✅ Terraform Apply - Crea toda la infraestructura (VPC, ALB, ECR, ECS, etc.)
3. ✅ Build - Construye todas las imágenes Docker
4. ✅ Push - Sube las imágenes a ECR
5. ✅ Deploy - Despliega los servicios en ECS
6. ✅ Reporte - Genera un HTML con toda la info y lo abre en el navegador

**Tiempo estimado:** 15-25 minutos

### Otros ambientes:

```bash
# Para stage
make setup-and-deploy ENV=stage

# Para prod
make setup-and-deploy ENV=prod
```

### Si la infraestructura ya existe:

```bash
# Solo rebuild y redeploy de servicios
make deploy-all ENV=dev
```

---

## 📦 Prerequisitos

### 1. Software Necesario

- **AWS CLI** configurado con credenciales válidas
- **Docker** instalado y funcionando
- **Terraform** >= 1.0.0
- **Make** (generalmente pre-instalado en macOS/Linux)

### 2. Permisos AWS Necesarios

Tu usuario/rol AWS debe tener permisos para:
- **VPC**: Crear VPCs, subnets, internet gateways, NAT gateways
- **ECS**: Crear clusters, task definitions, services
- **ECR**: Crear repositorios, push/pull de imágenes
- **ALB**: Crear load balancers, target groups, listeners
- **IAM**: Crear roles y políticas
- **CloudWatch**: Crear log groups
- **S3**: Crear buckets para Terraform state

---

## ⚙️ Setup Inicial del Backend S3

**IMPORTANTE:** Antes de ejecutar terraform por primera vez, debes configurar el backend S3.

### ¿Por qué es necesario?

El backend S3 permite:
- ✅ **Trabajo en equipo**: varios desarrolladores pueden colaborar
- ✅ **Prevenir conflictos**: solo una persona puede modificar a la vez (state locking)
- ✅ **Backup automático**: historial de cambios con versionado
- ✅ **Seguridad**: encriptación de datos sensibles

### Configurar Backend

```bash
# Opción 1: Usando make
make setup-backend

# Opción 2: Directamente con el script
./scripts/setup-terraform-backend.sh
```

Este script automáticamente:
1. Obtiene tu AWS Account ID
2. Crea el bucket S3 con el nombre `stockwiz-terraform-state-{ACCOUNT_ID}`
3. Habilita versionado y encriptación
4. Actualiza todos los archivos `main.tf` con tu bucket

**Solo necesitas ejecutarlo UNA VEZ por cuenta de AWS.**

---

## 🏗️ Deployment Completo

### Arquitectura Desplegada

```
Internet
   │
   ▼
Application Load Balancer (ALB)
   │
   ├─ /              → API Gateway (port 8000)
   ├─ /api/products  → Product Service (port 8001)
   └─ /api/inventory → Inventory Service (port 8002)
   │
   ▼
ECS Fargate Tasks (en subnets privadas)
   ├─ dev-stockwiz (Task)
   │  ├─ PostgreSQL
   │  ├─ Redis
   │  ├─ API Gateway
   │  ├─ Product Service
   │  └─ Inventory Service
   │
   └─ Auto-scaling (1-4 tasks según CPU/Memory)
```

### Infraestructura Creada

Al ejecutar `make setup-and-deploy ENV=dev`, se crea:

**Red y Seguridad:**
- ✅ VPC con subnets públicas y privadas
- ✅ Internet Gateway
- ✅ 2 NAT Gateways (alta disponibilidad)
- ✅ Security Groups configurados

**Balanceo de Carga:**
- ✅ Application Load Balancer (público)
- ✅ 3 Target Groups (uno por servicio)
- ✅ Health checks automáticos

**Repositorios de Imágenes:**
- ✅ 4 Repositorios ECR:
  - `dev-api-gateway`
  - `dev-product-service`
  - `dev-inventory-service`
  - `dev-postgres`

**Orquestación de Contenedores:**
- ✅ ECS Cluster con Fargate
- ✅ Task Definition (5 contenedores)
- ✅ ECS Service con auto-scaling
- ✅ CloudWatch Logs

**Monitoreo:**
- ✅ CloudWatch Dashboard
- ✅ Alarmas de health checks
- ✅ Alarmas de CPU/Memory
- ✅ Lambda para health checks
- ✅ SNS para notificaciones

---

## 🐳 Build y Push de Imágenes Docker

### Opción 1: Build y Push Automático (Recomendado)

```bash
# Build y push de todos los servicios
make ecr-build-push-all ENV=dev

# Build y push de un servicio específico
make ecr-build-push-all ENV=dev SERVICE=api-gateway
```

### Opción 2: Usando Scripts Directamente

```bash
# Build y push de todos los servicios
./scripts/build-and-push-ecr.sh dev all

# Build y push de un servicio específico
./scripts/build-and-push-ecr.sh dev api-gateway
./scripts/build-and-push-ecr.sh dev product-service
./scripts/build-and-push-ecr.sh dev inventory-service
```

**El script genera automáticamente tags:**
- `latest` - Siempre apunta a la última versión
- `{timestamp}-{git-hash}` - Ejemplo: `20251128-143025-a1b2c3d`

### Opción 3: Manual

```bash
# 1. Login a ECR
make ecr-login ENV=dev

# 2. Obtener URLs de repositorios
cd IaC/terraform/environments/dev
terraform output ecr_repositories

# 3. Build de cada imagen
docker build --platform linux/amd64 \
  -t api-gateway:latest \
  -f app/StockWiz/api-gateway/Dockerfile \
  app/StockWiz/api-gateway

# 4. Tag para ECR (reemplaza ACCOUNT_ID)
docker tag api-gateway:latest \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-api-gateway:latest

# 5. Push
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-api-gateway:latest
```

**Importante:** Usar `--platform linux/amd64` porque ECS Fargate requiere arquitectura AMD64.

### Verificar Imágenes en ECR

```bash
# Listar imágenes en un repositorio
aws ecr list-images \
  --repository-name dev-api-gateway \
  --region us-east-1

# Ver detalles de imágenes
aws ecr describe-images \
  --repository-name dev-api-gateway \
  --region us-east-1
```

---

## 🚢 Deploy a ECS

### Método 1: Deploy Completo (Recomendado)

Este método ejecuta todo: build, push y deploy.

```bash
# Desplegar todos los servicios
make deploy-all ENV=dev

# Desplegar un servicio específico
make deploy-all ENV=dev SERVICE=api-gateway
```

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
# Deploy completo (build + push + deploy)
./scripts/build-push-deploy.sh dev all

# Solo deploy a ECS
./scripts/deploy-to-ecs.sh dev all

# Deploy de un servicio específico
./scripts/deploy-to-ecs.sh dev api-gateway
```

### ¿Qué sucede durante un deploy?

1. **Force New Deployment**: ECS crea nuevas tareas con la última versión de la imagen
2. **Health Checks**: Las nuevas tareas deben pasar los health checks
3. **ALB Target Registration**: Las tareas se registran en el target group del ALB
4. **Rolling Update**:
   - Se crean nuevas tareas (hasta 200% = 2 tareas)
   - Una vez saludables, se eliminan las tareas viejas
   - Siempre hay al menos 1 tarea corriendo (100%)
5. **Stabilization**: El servicio se marca como estable

**Timeouts:**
- Health Check Grace Period: 60 segundos
- Health Check Interval: 30 segundos
- Tiempo total estimado: 2-5 minutos por servicio

---

## ✅ Verificación del Deployment

### Generar Reporte HTML

```bash
# Genera y abre reporte completo con URLs, health status, etc.
make report ENV=dev
```

El reporte incluye:
- URLs de todos los servicios
- Estado de health checks
- Información de infraestructura
- Logs recientes

### Verificación Manual

```bash
# 1. Obtener DNS del ALB
cd IaC/terraform/environments/dev
terraform output alb_dns_name

# 2. Probar endpoints
curl http://<ALB-DNS>/health
curl http://<ALB-DNS>/api/products
curl http://<ALB-DNS>/api/inventory

# 3. Ver estado de servicios ECS
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-stockwiz \
  --region us-east-1

# 4. Ver tareas corriendo
aws ecs list-tasks \
  --cluster dev-cluster \
  --region us-east-1

# 5. Ver logs en tiempo real
aws logs tail /ecs/dev --follow
```

---

## ⏮️ Rollback

Si necesitas hacer rollback a una versión anterior:

### Opción 1: Deploy de una imagen anterior

```bash
# 1. Listar imágenes disponibles en ECR
aws ecr describe-images \
  --repository-name dev-api-gateway \
  --region us-east-1

# 2. Actualizar la task definition para usar una imagen específica
# Editar: IaC/terraform/modules/ecs/main.tf
# Cambiar: image = "${var.api_gateway_ecr_url}:latest"
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

---

## 🔧 Troubleshooting

### Error: "no basic auth credentials"

**Solución:**
```bash
make ecr-login ENV=dev
```

### Error: "repository does not exist"

**Solución:**
```bash
# Asegúrate de haber aplicado Terraform primero
cd IaC/terraform/environments/dev
terraform apply
```

### Error: "Your authorization token has expired"

**Solución:**
```bash
make ecr-login ENV=dev
```

### Las tareas no se inician

**Problema**: Las tareas van a estado STOPPED

**Solución:**
```bash
# Ver razón del error
aws ecs describe-tasks \
  --cluster dev-cluster \
  --tasks <TASK-ARN> \
  --region us-east-1 \
  --query 'tasks[0].stoppedReason'

# Causas comunes:
# 1. Imagen no existe en ECR → Verificar ECR
# 2. Error de permisos IAM → Verificar taskRole
# 3. No hay IPs disponibles → Verificar subnets
```

### Health checks fallan

**Problema**: Las tareas no pasan health checks del ALB

**Solución:**
```bash
# 1. Verificar logs del contenedor
aws logs tail /ecs/dev --follow --filter-pattern "api-gateway"

# 2. Verificar que el endpoint /health responde

# 3. Ajustar health check grace period si es necesario
# Editar: IaC/terraform/modules/ecs/main.tf
# health_check_grace_period_seconds = 120  # Aumentar a 2 minutos
```

### Servicio no se estabiliza

**Problema**: El comando `aws ecs wait services-stable` timeout

**Solución:**
```bash
# Verificar eventos del servicio
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-stockwiz \
  --region us-east-1 \
  --query 'services[0].events[:10]'

# Ver tareas fallidas
aws ecs list-tasks \
  --cluster dev-cluster \
  --desired-status STOPPED \
  --region us-east-1
```

### AWS credentials expired (AWS Academy)

**Problema**: AWS Academy session timeout

**Solución:**
1. Ve a AWS Academy Learner Lab
2. Click "Start Lab"
3. Copia nuevas credentials (AWS Details → AWS CLI)
4. Actualiza las credenciales locales:
   ```bash
   aws configure
   # O actualiza ~/.aws/credentials
   ```

---

## 📊 Comandos Útiles

### Terraform

```bash
# Inicializar
make terraform-init ENV=dev

# Ver plan
make terraform-plan ENV=dev

# Aplicar
make terraform-apply ENV=dev

# Destruir
make terraform-destroy ENV=dev

# Ver outputs
cd IaC/terraform/environments/dev
terraform output
```

### Docker/ECR

```bash
# Login a ECR
make ecr-login ENV=dev

# Build y push todos los servicios
make ecr-build-push-all ENV=dev

# Ver URLs de ECR
make get-ecr-urls ENV=dev
```

### ECS

```bash
# Redesplegar servicios
make deploy-ecs ENV=dev

# Ver estado de servicios
aws ecs list-services --cluster dev-cluster --region us-east-1

# Ver tareas corriendo
aws ecs list-tasks --cluster dev-cluster --region us-east-1

# Ver logs en tiempo real
aws logs tail /ecs/dev --follow
```

### Reportes

```bash
# Generar y abrir reporte
make report ENV=dev

# Abrir reporte existente
make view-report ENV=dev
```

---

## 💰 Costos Estimados (us-east-1)

Para el ambiente dev con 1 tarea corriendo (5 contenedores):

- **Fargate Tasks**: ~$13/mes (2 vCPU, 4GB RAM)
- **ALB**: ~$16/mes
- **NAT Gateway**: ~$32/mes (2 NAT gateways)
- **CloudWatch Logs**: ~$1/mes
- **ECR Storage**: ~$1/mes (primeros 50GB)
- **Lambda + CloudWatch**: ~$1/mes

**Total estimado**: ~$64/mes

**Para reducir costos:**
- Detén los servicios cuando no los uses: `make terraform-destroy ENV=dev`
- Usa solo 1 NAT Gateway en desarrollo
- Reduce retención de logs a 1-3 días

---

## 🔗 Documentación Relacionada

- [README.md](README.md) - Introducción y arquitectura general
- [TESTING.md](TESTING.md) - Guía de testing
- [PIPELINE.md](PIPELINE.md) - CI/CD pipeline
- [MONITORING.md](MONITORING.md) - Monitoreo y alertas

---
