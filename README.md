# StockWiz - Sistema de Gestión de Productos e Inventario

Sistema de microservicios para gestión de productos e inventario con deployment automatizado en AWS.

---

## Índice

- [Descripción](#descripción)
- [Inicio Rápido](#inicio-rápido)
- [Arquitectura](#arquitectura)
- [Componentes](#componentes)
- [Infraestructura](#infraestructura)
- [Documentación](#documentación)
- [Comandos](#comandos)

---

## Descripción

StockWiz es una aplicación de gestión de productos e inventario construida con arquitectura de microservicios:

- **Microservicios**: API Gateway, Product Service, Inventory Service
- **Contenedorización**: Docker + Amazon ECS Fargate
- **Infraestructura como Código**: Terraform
- **CI/CD**: GitHub Actions
- **Alta Disponibilidad**: Multi-AZ con auto-scaling
- **Monitoreo**: CloudWatch (dashboards, alarmas, Lambda health checker)
- **Calidad de Código**: SonarCloud con quality gates

---

## Inicio Rápido

### Prerequisitos

- AWS CLI configurado
- Docker instalado
- Terraform >= 1.0.0

### Setup Backend S3 (primera vez)

```bash
make setup-backend
```

### Deployment

```bash
# Desarrollo
make setup-and-deploy ENV=dev

# Staging
make setup-and-deploy ENV=stage

# Producción
make setup-and-deploy ENV=prod
```

El comando ejecuta:
1. Terraform init y apply (VPC, ALB, ECR, ECS)
2. Build de imágenes Docker
3. Push a ECR
4. Deploy a ECS
5. Generación de reporte HTML

Tiempo estimado: 15-25 minutos

### Verificación

```bash
make report ENV=dev
```

### Testing Local

```bash
# Tests unitarios (Docker)
./scripts/run-tests-docker.sh

# Git hook pre-push
./scripts/setup-git-hooks.sh
```

---

## Arquitectura

```
Internet
   │
   ▼
Application Load Balancer (ALB)
   │
   ├─ /              → API Gateway (8000)
   ├─ /api/products  → Product Service (8001)
   └─ /api/inventory → Inventory Service (8002)
   │
   ▼
ECS Fargate Task
   ├─ PostgreSQL
   ├─ Redis
   ├─ API Gateway (Go)
   ├─ Product Service (Python/FastAPI)
   └─ Inventory Service (Go)
```

### Flujo

1. Requests de usuarios llegan al ALB
2. ALB distribuye tráfico según path rules
3. Todos los contenedores corren en la misma Task de ECS
4. Comunicación inter-servicios via localhost
5. Auto-scaling basado en CPU/Memory (1-4 tasks)

---

## Componentes

### API Gateway (8000)

- **Stack**: Go
- **Función**: Frontend web, routing, caché Redis

### Product Service (8001)

- **Stack**: Python + FastAPI
- **Función**: CRUD de productos, PostgreSQL, Redis cache

### Inventory Service (8002)

- **Stack**: Go
- **Función**: Gestión de inventario, PostgreSQL

### PostgreSQL

Base de datos relacional (productos, inventario)

### Redis

Caché in-memory, TTL 5 minutos

---

## Infraestructura

### Módulos Terraform

```
IaC/terraform/
├── modules/
│   ├── vpc/          # Networking
│   ├── alb/          # Load balancing
│   ├── ecr/          # Container registry
│   ├── ecs/          # Container orchestration
│   └── monitoring/   # CloudWatch
└── environments/
    ├── dev/
    ├── stage/
    └── prod/
```

### Recursos por Ambiente

- VPC (2 AZs, subnets públicas/privadas)
- Application Load Balancer
- 4 Repositorios ECR
- ECS Cluster + Auto-scaling (1-4 tasks)
- CloudWatch (dashboard, alarmas)
- Lambda (health checks cada 5min)

---

## CI/CD Pipeline

```
Push → Tests → SonarCloud → Build → Deploy → Tests funcionales
```

- Tests automáticos (Python pytest, Go test)
- Quality Gates (coverage ≥80%)
- Deploy automático a ECS
- Tests funcionales (Newman)

Tiempo: 18-28 minutos

Documentación: [PIPELINE.md](PIPELINE.md)

---

## Monitoreo

### SonarCloud

- Quality Gates: coverage ≥80%, 0 bugs críticos
- Análisis automático en PRs

### CloudWatch

- Métricas: CPU, memoria, ALB, Lambda
- Alarmas con notificación email (SNS)
- Health checks cada 5 minutos

Documentación: [MONITORING.md](MONITORING.md)

---

## Testing

```bash
# Tests unitarios (Docker)
./scripts/run-tests-docker.sh

# Git hook pre-push
./scripts/setup-git-hooks.sh

# Tests funcionales
./scripts/run-functional-tests.sh dev
```

Documentación: [TESTING.md](TESTING.md)

---

## Documentación

| Documento | Contenido |
|-----------|-----------|
| [DEPLOYMENT.md](DEPLOYMENT.md) | Terraform, ECR, ECS, rollback |
| [TESTING.md](TESTING.md) | Tests unitarios, funcionales, coverage |
| [PIPELINE.md](PIPELINE.md) | CI/CD, jobs, troubleshooting |
| [MONITORING.md](MONITORING.md) | SonarCloud, CloudWatch, alertas |

---

## Comandos

### Terraform

```bash
make terraform-init ENV=dev
make terraform-plan ENV=dev
make terraform-apply ENV=dev
make terraform-destroy ENV=dev
```

### Docker/ECR

```bash
make ecr-login ENV=dev
make ecr-build-push-all ENV=dev
```

### ECS

```bash
make deploy-ecs ENV=dev
make deploy-all ENV=dev
```

### Testing

```bash
./scripts/run-tests-docker.sh
./scripts/run-functional-tests.sh dev
```

### Logs

```bash
aws logs tail /ecs/dev --follow
aws logs tail /ecs/dev --filter-pattern "product-service"
```

---

## Costos

Estimado mensual ambiente dev (us-east-1):

- Fargate (2 vCPU, 4GB): ~$13
- ALB: ~$16
- NAT Gateway (2x): ~$32
- CloudWatch/ECR/Lambda: ~$3

Total: ~$64/mes

---

## Workflow de Desarrollo

```bash
# 1. Feature branch
git checkout -b feature/nueva-funcionalidad

# 2. Tests locales
./scripts/run-tests-docker.sh

# 3. Push
git push origin feature/nueva-funcionalidad

# 4. PR (pipeline automático)
```

---

**Autores**: Federico Roldós, Michael Rodríguez

---
