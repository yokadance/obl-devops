# Monitoring & Quality Guide - StockWiz

Guía completa de monitoreo, alertas y análisis de calidad de código.

---

## 📋 Tabla de Contenidos

- [SonarCloud - Análisis de Calidad](#-sonarcloud---análisis-de-calidad)
- [CloudWatch - Monitoreo de Infraestructura](#-cloudwatch---monitoreo-de-infraestructura)
- [Testing de Alertas](#-testing-de-alertas)
- [Troubleshooting](#-troubleshooting)

---

## 🔍 SonarCloud - Análisis de Calidad

SonarCloud analiza automáticamente la calidad del código en cada push/PR.

### Objetivo

Implementar análisis automático de calidad de código con:
- ✅ Cobertura de tests
- ✅ Detección de bugs y vulnerabilidades
- ✅ Code smells y duplicación
- ✅ Quality Gates automáticos
- ✅ Integración con GitHub PRs

### Setup Paso a Paso

#### 1. Crear cuenta en SonarCloud

1. Ve a [https://sonarcloud.io](https://sonarcloud.io)
2. Click en **"Log in"**
3. Selecciona **"With GitHub"**
4. Autoriza SonarCloud para acceder a tu GitHub

#### 2. Importar el proyecto

1. En SonarCloud dashboard, click en **"+"** → **"Analyze new project"**
2. Selecciona tu organización de GitHub
3. Busca el repositorio **"obl-devops"**
4. Click en **"Set Up"**

#### 3. Configurar el proyecto

1. **Choose your Analysis Method**: Selecciona **"With GitHub Actions"**
2. SonarCloud te mostrará:
   - `SONAR_TOKEN`: Token de autenticación
   - `SONAR_ORGANIZATION`: Tu organización
   - `SONAR_PROJECT_KEY`: Clave del proyecto

3. **IMPORTANTE**: Copia estos valores

#### 4. Configurar GitHub Secrets

1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. Click en **"New repository secret"**

Agrega los siguientes secrets:

| Secret Name | Descripción |
|-------------|-------------|
| `SONAR_TOKEN` | Token de autenticación de SonarCloud |
| `SONAR_ORGANIZATION` | Tu organización en SonarCloud |
| `SONAR_PROJECT_KEY` | Clave del proyecto (ej: `stockwiz-devops`) |

**Ejemplo:**
```
SONAR_TOKEN: sqp_abc123def456...
SONAR_ORGANIZATION: tu-username
SONAR_PROJECT_KEY: stockwiz-devops
```

#### 5. Desactivar Automatic Analysis

**IMPORTANTE**: Desactiva el análisis automático de SonarCloud para evitar duplicados.

1. En SonarCloud, selecciona el proyecto "obl-devops"
2. Administration (menú lateral izquierdo) → Analysis Method
3. Deshabilita "Automatic Analysis"

### Quality Gates

El proyecto usa los Quality Gates por defecto de SonarCloud:

- ✅ Coverage ≥ 80%
- ✅ 0 bugs de severidad alta
- ✅ 0 vulnerabilidades
- ✅ Duplicación ≤ 3%
- ✅ Code smells ≤ 0.8% (rating A)

**Nota**: SonarCloud Free solo permite usar Quality Gates por defecto. Para personalizarlos, se requiere plan de pago.

### Estructura del Proyecto

El análisis cubre los siguientes servicios:

```
app/StockWiz/
├── api-gateway/          # Go - API Gateway
│   ├── main.go
│   ├── go.mod
│   └── coverage.out      (auto-generado)
│
├── inventory-service/    # Go - Inventory Service
│   ├── main.go
│   ├── go.mod
│   └── coverage.out      (auto-generado)
│
└── product-service/      # Python - Product Service
    ├── main.py
    ├── requirements.txt
    └── coverage.xml       (auto-generado)
```

### Flujo de Trabajo

Cuando haces un commit/PR:

1. **GitHub Actions se dispara** automáticamente
2. **Ejecuta tests** de Python y Go con cobertura
3. **SonarCloud analiza** el código:
   - Bugs
   - Vulnerabilities
   - Code Smells
   - Duplicación
   - Cobertura de tests
4. **Quality Gate evalúa** si el código cumple los estándares
5. **Resultado en el PR**:
   - ✅ Quality Gate passed → Código aprobado
   - ❌ Quality Gate failed → Revisar issues

### Ver Resultados

#### En SonarCloud Dashboard

1. Ve a [https://sonarcloud.io](https://sonarcloud.io)
2. Selecciona el proyecto **"obl-devops"**

Verás:
- **Overview**: Resumen general
- **Issues**: Bugs, Vulnerabilities, Code Smells
- **Security Hotspots**: Puntos de revisión de seguridad
- **Measures**: Métricas detalladas
- **Code**: Navegación por archivos con issues

#### En GitHub PR

Cuando creas un Pull Request, verás:
- ✅ **SonarCloud Quality Gate** check
- Click en "Details" para ver el análisis completo en SonarCloud

---

## 📊 CloudWatch - Monitoreo de Infraestructura

CloudWatch monitorea la infraestructura AWS y envía alertas cuando hay problemas.

### Dashboard

El dashboard de CloudWatch incluye:

**Métricas de ECS:**
- CPU Utilization
- Memory Utilization
- Número de tareas running/pending/stopped

**Métricas de ALB:**
- Request Count
- Target Response Time
- Healthy/Unhealthy Target Count
- HTTP 4xx/5xx errors

**Métricas de Lambda:**
- Invocations
- Duration
- Errors

**Health Checks:**
- HTTP Health Check Status
- Database Connection Status
- Redis Connection Status

### Alarmas Configuradas

**1. Health Check Alarms**

| Alarma | Condición | Threshold |
|--------|-----------|-----------|
| `dev-health-check-http-failed` | HTTP health check falla | ≥ 1 en 2 períodos de 5 min |
| `dev-health-check-database-failed` | Database health check falla | ≥ 1 en 2 períodos de 5 min |
| `dev-health-check-redis-failed` | Redis health check falla | ≥ 1 en 2 períodos de 5 min |

**2. Resource Alarms**

| Alarma | Condición | Threshold |
|--------|-----------|-----------|
| `dev-cpu-high` | Uso de CPU alto | > 80% por 10 min |
| `dev-memory-high` | Uso de memoria alto | > 85% por 10 min |

**3. ALB Alarms**

| Alarma | Condición | Threshold |
|--------|-----------|-----------|
| `dev-alb-unhealthy-targets` | Targets unhealthy | ≥ 1 por 5 min |
| `dev-alb-5xx-errors` | Errores 5xx | > 10 en 5 min |

### Notificaciones

Las alarmas envían notificaciones via **SNS** (Simple Notification Service).

**Configurar email para recibir alertas:**

1. Edita `IaC/terraform/environments/dev/main.tf`:

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  environment      = var.environment
  aws_region       = var.aws_region
  alb_dns_name     = module.alb.alb_dns_name
  ecs_cluster_name = module.ecs.cluster_name
  alert_email      = "tu-email@example.com"  # ← Agrega esta línea

  depends_on = [module.alb, module.ecs]
}
```

2. Aplica los cambios:
```bash
terraform -chdir=IaC/terraform/environments/dev apply
```

3. **IMPORTANTE**: Confirma la suscripción del email en tu bandeja de entrada.

### Health Checker Lambda

La Lambda `dev-stockwiz-health-checker` ejecuta cada 5 minutos y:

1. Hace health checks a todos los endpoints:
   - `GET {ALB_DNS}/health` → API Gateway
   - `GET {ALB_DNS}/api/products/health` → Product Service
   - `GET {ALB_DNS}/api/inventory/health` → Inventory Service

2. Verifica conectividad a:
   - PostgreSQL
   - Redis

3. Envía métricas a CloudWatch:
   - `HealthCheck-HTTP`: 1 (success) o 0 (failure)
   - `HealthCheck-Database`: 1 (success) o 0 (failure)
   - `HealthCheck-Redis`: 1 (success) o 0 (failure)

4. CloudWatch evalúa las métricas y activa alarmas si es necesario

5. SNS envía notificación por email si alarma se activa

---

## 🧪 Testing de Alertas

Se pueden probar que las alertas funcionan correctamente simulando fallos.

### Prueba 1: Simular Falla de Health Check (RECOMENDADO)

Esta es la forma más segura. No causa downtime real.

```bash
./scripts/test-cloudwatch-alerts.sh dev database
```

Selecciona opción `1` cuando se te pregunte.

**Qué hace:**
- Invoca la Lambda con un flag especial
- La Lambda envía métricas de falla para los últimos 15 minutos
- CloudWatch detecta las métricas malas
- Alarmas se activan después de 2 períodos consecutivos (10 min)

**Monitorear:**

```bash
# Ver estado de alarmas
aws cloudwatch describe-alarms \
  --alarm-name-prefix "dev-" \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table

# Ver logs de Lambda
aws logs tail /aws/lambda/dev-stockwiz-health-checker --follow

# Ver dashboard
make report ENV=dev
```

### Prueba 2: Simular Alto CPU/Memory

Envía métricas altas directamente a CloudWatch.

```bash
./scripts/test-cloudwatch-alerts.sh dev cpu
```

Selecciona opción `2`.

**Qué hace:**
- Envía métricas de CPU/Memory al 95%
- Alarmas de CPU/Memory se activan
- No causa impacto real en el servicio

### Prueba 3: Parar Servicio ECS (⚠️ causa downtime)

**ADVERTENCIA**: Esto causa downtime real. Solo para testing.

```bash
./scripts/test-cloudwatch-alerts.sh dev database
```

Selecciona opción `3`.

**Qué hace:**
- Para el servicio ECS real
- Todas las alarmas se activan
- El servicio queda inaccesible

**Restaurar:**
```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-stockwiz \
  --desired-count 1
```

### Comandos Útiles

**Ver todas las alarmas:**
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix "dev-" \
  --region us-east-1
```

**Ver métricas de health check:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace "StockWiz/dev" \
  --metric-name "HealthCheck-HTTP" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Resetear alarma manualmente:**
```bash
aws cloudwatch set-alarm-state \
  --alarm-name "dev-health-check-http-failed" \
  --state-value OK \
  --state-reason "Manual reset for testing"
```

**Invocar Lambda manualmente:**
```bash
aws lambda invoke \
  --function-name dev-stockwiz-health-checker \
  --payload '{"simulate_failure":true,"failure_type":"database"}' \
  response.json

cat response.json | jq .
```

### Estados de Alarma

- **OK**: Todo funciona correctamente
- **ALARM**: Condición de alarma cumplida
- **INSUFFICIENT_DATA**: No hay suficientes datos para evaluar

### Configurar Múltiples Emails

Si quieres que múltiples personas reciban alertas:

1. Ve a la consola de SNS: https://console.aws.amazon.com/sns
2. Busca el topic: `dev-stockwiz-alerts`
3. Click en "Create subscription"
4. Protocol: Email
5. Endpoint: otro-email@example.com
6. Confirma el email

---

## 🔍 Troubleshooting

### SonarCloud

#### Quality Gate falla

**Causa:** SonarCloud detectó issues que no cumplen los umbrales

**Solución:**
1. Ve al dashboard de SonarCloud
2. Revisa la sección "Issues"
3. Corrige los issues detectados:
   - Bugs → Errores lógicos
   - Vulnerabilities → Problemas de seguridad
   - Code Smells → Código que debería mejorarse
4. Sube coverage si está por debajo del 80%

#### Tests no se ejecutan en CI/CD

**Solución:**
```bash
# Verificar que los tests pasen localmente
./scripts/run-tests-docker.sh

# Verificar GitHub Secrets
# Settings → Secrets → Actions
# Debe tener SONAR_TOKEN, SONAR_ORGANIZATION, SONAR_PROJECT_KEY
```

### CloudWatch

#### No recibo emails

**Solución:**
1. Verifica que confirmaste la suscripción de email
2. Revisa spam/junk
3. Verifica el topic SNS:
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:dev-stockwiz-alerts
```

#### Alarmas no se activan

**Solución:**
1. Verifica que la Lambda esté ejecutando:
```bash
aws logs tail /aws/lambda/dev-stockwiz-health-checker --follow
```

2. Verifica que las métricas se estén enviando:
```bash
aws cloudwatch list-metrics --namespace "StockWiz/dev"
```

3. Verifica la configuración de la alarma:
```bash
aws cloudwatch describe-alarms --alarm-names "dev-health-check-http-failed"
```

#### Alarmas siempre en estado INSUFFICIENT_DATA

**Causa:** No hay suficientes puntos de datos

**Solución:**
1. Espera 10-15 minutos para que se acumulen datos
2. Verifica que la Lambda esté ejecutando cada 5 minutos
3. Ejecuta el script de prueba para generar datos:
```bash
./scripts/test-cloudwatch-alerts.sh dev database
```

---

## 📚 Referencias

### SonarCloud
- [SonarCloud Documentation](https://docs.sonarcloud.io/)
- [Quality Gates](https://docs.sonarcloud.io/improving/quality-gates/)
- [Python Coverage](https://docs.sonarcloud.io/enriching/test-coverage/python-test-coverage/)
- [Go Coverage](https://docs.sonarcloud.io/enriching/test-coverage/go-test-coverage/)

### CloudWatch
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [SNS Email Notifications](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html)
- [Lambda Metrics](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-metrics.html)

---

## 🔗 Documentación Relacionada

- [README.md](README.md) - Introducción y arquitectura general
- [DEPLOYMENT.md](DEPLOYMENT.md) - Guía de deployment
- [TESTING.md](TESTING.md) - Guía de testing
- [PIPELINE.md](PIPELINE.md) - CI/CD pipeline

---
