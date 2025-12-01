# 🚀 Pipeline CI/CD - StockWiz

Pipeline automatizado que ejecuta tests, análisis de calidad y deployment automático a AWS ECS.

## 📋 Tabla de Contenidos

- [Flujo del Pipeline](#flujo-del-pipeline)
- [Triggers](#triggers)
- [Jobs y Etapas](#jobs-y-etapas)
- [Requisitos](#requisitos)
- [Variables y Secrets](#variables-y-secrets)
- [Uso](#uso)
- [Troubleshooting](#troubleshooting)

---

## 🔄 Flujo del Pipeline

```mermaid
graph TD
    A[Push/PR a develop/dev] --> B[Job 1: Tests & SonarCloud]
    B --> C{Quality Gate Passed?}
    C -->|❌ Failed| D[Pipeline STOPS]
    C -->|✅ Passed| E[Job 2: Build & Push to ECR]
    E --> F[Job 3: Deploy to ECS Dev]
    F --> G[Job 4: Health Checks]
    G --> H[Job 5: Notification]
```

### Fases del Pipeline:

1. **Tests & Quality Analysis** (7-10 min)
   - Python tests con pytest
   - Go tests con coverage
   - SonarCloud análisis
   - Quality Gate validation

2. **Build & Push** (5-8 min)
   - Build de 3 imágenes Docker
   - Push a ECR con tags: `latest` + `git-sha`

3. **Deploy to ECS** (3-5 min)
   - Update de 3 servicios ECS
   - Wait for stabilization
   - Health checks

4. **Notification** (1 min)
   - Summary en GitHub Actions
   - Estado de cada etapa

**Tiempo total estimado:** 16-24 minutos

---

## 🎯 Triggers

### Push Events (Auto-deploy)
```yaml
Branches:
  - dev

Paths monitoreados:
  - app/StockWiz/**
  - IaC/terraform/**
  - .github/workflows/dev-pipeline.yml
```

**Comportamiento:**
- ✅ Ejecuta TODO el pipeline (tests → build → deploy)
- ✅ Deploy automático si Quality Gate pasa
- ❌ NO se ejecuta en PRs (solo tests)

### Pull Request Events (Tests only)
```yaml
Branches base:
  - develop
  - dev

Tipos:
  - opened
  - synchronize
  - reopened
```

**Comportamiento:**
- ✅ Ejecuta SOLO tests y SonarCloud
- ❌ NO hace build ni deploy
- ✅ Bloquea merge si Quality Gate falla

---

## 🏗️ Jobs y Etapas

### Job 1: `test-and-quality` 🧪

**Propósito:** Ejecutar tests unitarios y análisis de calidad de código

**Pasos:**
1. Checkout con submódulos
2. Setup Python 3.11
3. Instalar dependencias Python (pytest, pytest-cov, httpx)
4. Ejecutar pytest con coverage para `product-service`
5. Setup Go 1.21
6. Ejecutar tests Go para `api-gateway`
7. Ejecutar tests Go para `inventory-service`
8. SonarCloud scan
9. Quality Gate check (❌ FALLA si QG no pasa)
10. Upload coverage reports

**Outputs:**
- `quality-gate-status`: "PASSED" o "FAILED"


---

### Job 2: `build-and-push` 🏗️

**Propósito:** Construir imágenes Docker y subirlas a ECR

**Condiciones:**
- ✅ `test-and-quality` debe pasarse previamente
- ✅ Solo en push (NO en PRs)
- ✅ Solo en branches `develop` o `dev`

**Pasos:**
1. Checkout con submódulos
2. Configure AWS credentials
3. Login a Amazon ECR
4. Build + Push `api-gateway`:
   - Tag: `{ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/dev-api-gateway:latest`
   - Tag: `{ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/dev-api-gateway:{git-sha}`
5. Build + Push `product-service`
6. Build + Push `inventory-service`

**Outputs:**
- `image-tags`: Git SHA usado como tag

**Servicios construidos:**
```
dev-api-gateway:latest
dev-api-gateway:{git-sha}

dev-product-service:latest
dev-product-service:{git-sha}

dev-inventory-service:latest
dev-inventory-service:{git-sha}
```

---

### Job 3: `deploy-to-ecs` 🚢

**Propósito:** Desplegar servicios actualizados a ECS Dev

**Condiciones:**
- ✅ `build-and-push` debe completarse exitosamente
- ✅ Solo en push (NO en PRs)

**Pasos:**
1. Configure AWS credentials
2. Update ECS Service: `dev-api-gateway` (force new deployment)
3. Update ECS Service: `dev-product-service`
4. Update ECS Service: `dev-inventory-service`
5. Wait for services-stable (hasta 10 min timeout)
6. Get ALB DNS name
7. Health checks:
   - `GET http://{ALB_DNS}/health` → API Gateway
   - `GET http://{ALB_DNS}/products/health` → Product Service
   - `GET http://{ALB_DNS}/inventory/health` → Inventory Service

**Deployment Strategy:**
- Rolling update
- Force new deployment (pull latest image)
- Wait for stability antes de marcar como exitoso

---

### Job 4: `functional-tests` 🧪

**Propósito:** Ejecutar tests funcionales de endpoints con Newman

**Condiciones:**
- ✅ `deploy-to-ecs` debe completarse exitosamente
- ✅ Solo en push (NO en PRs)

**Pasos:**
1. Configure AWS credentials
2. Get ALB DNS
3. Install Newman + newman-reporter-htmlextra
4. Wait for services to be ready (retry con backoff)
5. Update environment file con ALB DNS
6. Run Postman collection:
   - Health checks
   - Product Service CRUD tests
   - Inventory Service CRUD tests
   - Integration tests
7. Generate HTML report
8. Upload report artifact

**Tests ejecutados:**
- Status code validation
- Response structure validation
- Response time validation (< 2-3s)
- Data integrity validation

**Artifacts:**
- `newman-test-report` → HTML report con resultados detallados

---

### Job 5: `notify` 📢

**Propósito:** Generar resumen del pipeline

**Condiciones:**
- ✅ Siempre se ejecuta (even if previous jobs fail)

**Output:**
```markdown
## 📊 Pipeline Execution Summary

| Stage | Status |
|-------|--------|
| Tests & Quality | success |
| Build & Push | success |
| Deploy to ECS | success |
| Functional Tests | success |

### ✅ Deployment & Tests Successful!
The application has been successfully deployed to the **dev** environment and all functional tests passed.
```

---

## 🔐 Requisitos

### GitHub Secrets Necesarios:

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_SESSION_TOKEN` | AWS Session Token (AWS Academy) | `FwoGZXIvYXdzE...` |
| `SONAR_TOKEN` | SonarCloud Authentication Token | `sqp_abc123...` |
| `SONAR_ORGANIZATION` | SonarCloud Organization | `tu-username` |
| `SONAR_PROJECT_KEY` | SonarCloud Project Key | `stockwiz-devops` |

### Infraestructura AWS Requerida:

- ✅ ECS Cluster: `dev-cluster`
- ✅ ECS Services:
  - `dev-api-gateway`
  - `dev-product-service`
  - `dev-inventory-service`
- ✅ ECR Repositories:
  - `dev-api-gateway`
  - `dev-product-service`
  - `dev-inventory-service`
- ✅ ALB: `dev-stockwiz-alb`
- ✅ VPC, Subnets, Security Groups configurados

---

## 🚀 Uso

### Escenario 1: Desarrollo Normal

```bash
# 1. Crear feature branch
git checkout -b feature/nueva-funcionalidad

# 2. Hacer cambios en el código
cd app/StockWiz/product-service

# 3. Commit y push
git add .
git commit -m "feat: nueva funcionalidad"
git push origin feature/nueva-funcionalidad


```

### Escenario 2: Hotfix en Dev

```bash
# 1. Push directo a develop (emergency)
git checkout develop
git pull origin develop

# 2. Hacer fix
# ... cambios ...

# 3. Commit y push
git add .
git commit -m "fix: critical bug"
git push origin develop

# → Pipeline automático: tests → build → deploy
# → En 16-24 minutos está en producción dev
```

### Escenario 3: Solo quiero ver tests (sin deploy)

```bash
# Opción 1: Crear PR sin mergear
# → Solo ejecuta Job 1 (tests)

# Opción 2: Push a branch que NO sea develop/dev
git push origin feature/test-branch
# → NO se ejecuta el pipeline dev
# → Usa el pipeline de SonarCloud standalone
```

---

## 📊 Monitoring del Pipeline

### Ver ejecución en tiempo real:

1. Ve a **GitHub** → **Actions**
2. Selecciona workflow: **"🚀 Dev Environment - CI/CD Pipeline"**
3. Click en la ejecución más reciente

### Interpretar el estado:

| Estado Job | Significado | Acción |
|------------|-------------|--------|
| 🟢 `test-and-quality` | Tests pasaron, QG OK | Continúa a build |
| 🔴 `test-and-quality` | Tests fallaron o QG failed | Pipeline STOP, revisar código |
| 🟢 `build-and-push` | Imágenes en ECR | Continúa a deploy |
| 🔴 `build-and-push` | Error en build | Revisar Dockerfile |
| 🟢 `deploy-to-ecs` | Deployment exitoso | ✅ Listo |
| 🔴 `deploy-to-ecs` | Deploy falló | Revisar ECS logs |

---

## 🔍 Troubleshooting

### Error: "Quality Gate failed"

**Causa:** SonarCloud detectó issues que no cumplen los umbrales

**Solución:**
Revisar SQ y arreglar lo que este mal

---

### Error: "Docker build failed"

**Causa:** Error en Dockerfile o dependencias

**Solución:**
1. Build local para reproducir:
```bash
cd app/StockWiz/api-gateway
docker build -t test-build .
```

---


### Error: "AWS credentials expired"

**Causa:** AWS Academy session timeout

**Solución:**
1. Ve a AWS Academy Learner Lab
2. Click "Start Lab"
3. Copia nuevas credentials (AWS Details → AWS CLI)
4. Actualiza GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`

---


## 📈 Métricas del Pipeline

### Performance esperado:

| Métrica | Valor Esperado | Crítico si > |
|---------|----------------|--------------|
| Tiempo total | 18-28 min | 35 min |
| Tests Python | 1-2 min | 5 min |
| Tests Go | 2-3 min | 7 min |
| SonarCloud | 3-5 min | 10 min |
| Docker builds | 5-8 min | 15 min |
| ECS deploy | 3-5 min | 10 min |
| Functional tests | 2-4 min | 8 min |

---

## 🔗 Links Útiles

- **GitHub Actions:** https://github.com/{org}/obl-devops/actions
- **SonarCloud Dashboard:** https://sonarcloud.io/project/overview?id=stockwiz-devops
- **AWS ECS Console:** https://console.aws.amazon.com/ecs/home?region=us-east-1
- **CloudWatch Logs:** https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups

---

## 📚 Documentación Relacionada

- [README.md](README.md) - Introducción y arquitectura general
- [DEPLOYMENT.md](DEPLOYMENT.md) - Guía de deployment
- [TESTING.md](TESTING.md) - Guía de testing
- [MONITORING.md](MONITORING.md) - Monitoreo y alertas

---
