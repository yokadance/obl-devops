# Módulo de Monitoring

Este módulo implementa un sistema completo de monitoreo para StockWiz usando CloudWatch y Lambda.

## Componentes

### 1. Lambda Function - Health Checker

**Nombre**: `{environment}-stockwiz-health-checker`

**Función**: Verifica la salud de los servicios cada 5 minutos

**Checks que realiza**:
- ✅ HTTP (puerto 80) - `/health`
- ✅ HTTPS (puerto 443) - `/health`
- ✅ API Gateway - `/`
- ✅ Products API - `/api/products`
- ✅ Inventory API - `/api/inventory`

**Métricas enviadas a CloudWatch**:
- `HealthCheck-{Service}`: 1 si healthy, 0 si unhealthy
- `ResponseTime-{Service}`: Tiempo de respuesta en milisegundos

**Ejecución**: Automática cada 5 minutos vía EventBridge

### 2. CloudWatch Dashboard

**Nombre**: `{environment}-stockwiz-dashboard`

**Widgets incluidos**:
1. **Health Checks Status** - Estado de todos los health checks
2. **Response Times** - Tiempos de respuesta de cada endpoint
3. **ECS CPU Utilization** - Uso de CPU del cluster ECS
4. **ECS Memory Utilization** - Uso de memoria del cluster ECS
5. **API Gateway Requests** - Total de requests al ALB
6. **ALB Target Response Time** - Tiempo de respuesta del ALB
7. **HTTP Response Codes** - Códigos 2XX, 4XX, 5XX
8. **Lambda Invocations** - Invocaciones del health checker

### 3. CloudWatch Alarms

Se crean las siguientes alarmas automáticas:

#### Health Check Alarms
- `{environment}-health-check-http-failed` - HTTP health check falló
- `{environment}-health-check-https-failed` - HTTPS health check falló

#### ECS Alarms
- `{environment}-ecs-cpu-high` - CPU > 80% por 10 minutos
- `{environment}-ecs-memory-high` - Memoria > 80% por 10 minutos

#### ALB Alarms
- `{environment}-alb-5xx-errors` - Más de 10 errores 5XX en 5 minutos

## Uso

### Integrar en un environment

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  environment      = var.environment
  aws_region       = var.aws_region
  alb_dns_name     = module.alb.alb_dns_name
  ecs_cluster_name = module.ecs.cluster_name

  depends_on = [module.alb, module.ecs]
}
```

### Outputs disponibles

```hcl
# Dashboard name
output "dashboard_name" {
  value = module.monitoring.dashboard_name
}

# Dashboard URL
output "dashboard_url" {
  value = module.monitoring.dashboard_url
}

# Lambda function name
output "lambda_function_name" {
  value = module.monitoring.lambda_function_name
}

# Alarm names
output "alarms" {
  value = module.monitoring.alarms
}
```

## Comandos útiles

### Ver Dashboard
```bash
# Obtener URL del dashboard
terraform output cloudwatch_dashboard_url

# O abrirlo directamente
open $(terraform output -raw cloudwatch_dashboard_url)
```

### Invocar Lambda manualmente
```bash
aws lambda invoke \
  --function-name dev-stockwiz-health-checker \
  --region us-east-1 \
  response.json

cat response.json | jq .
```

### Ver métricas
```bash
# Ver métricas de health check HTTP
aws cloudwatch get-metric-statistics \
  --namespace "StockWiz/dev" \
  --metric-name "HealthCheck-HTTP" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-east-1
```

### Ver logs de Lambda
```bash
aws logs tail /aws/lambda/dev-stockwiz-health-checker --follow
```

### Ver estado de alarmas
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix "dev-" \
  --region us-east-1
```

## Métricas Custom

El módulo crea métricas custom en el namespace `StockWiz/{environment}`:

| Métrica | Descripción | Unidad |
|---------|-------------|--------|
| HealthCheck-HTTP | Estado del health check HTTP | None (0 o 1) |
| HealthCheck-HTTPS | Estado del health check HTTPS | None (0 o 1) |
| HealthCheck-APIGateway | Estado del API Gateway | None (0 o 1) |
| HealthCheck-Products | Estado del servicio de productos | None (0 o 1) |
| HealthCheck-Inventory | Estado del servicio de inventario | None (0 o 1) |
| ResponseTime-HTTP | Tiempo de respuesta HTTP | Milliseconds |
| ResponseTime-HTTPS | Tiempo de respuesta HTTPS | Milliseconds |
| ResponseTime-APIGateway | Tiempo de respuesta API Gateway | Milliseconds |
| ResponseTime-Products | Tiempo de respuesta productos | Milliseconds |
| ResponseTime-Inventory | Tiempo de respuesta inventario | Milliseconds |

## Costos

Costos aproximados mensuales (us-east-1):

- **Lambda**: ~$0.20/mes (12 invocaciones/hora * 30s cada una)
- **CloudWatch Logs**: ~$0.50/mes (500 MB/mes estimado)
- **CloudWatch Metrics**: ~$1.50/mes (10 métricas custom)
- **CloudWatch Alarms**: ~$0.50/mes (5 alarmas)
- **CloudWatch Dashboard**: ~$3.00/mes (1 dashboard)

**Total estimado**: ~$5.70/mes por ambiente

## Variables

| Variable | Descripción | Tipo | Default |
|----------|-------------|------|---------|
| environment | Environment name | string | - |
| aws_region | AWS Region | string | us-east-1 |
| alb_dns_name | ALB DNS name | string | - |
| ecs_cluster_name | ECS Cluster name | string | - |

## Outputs

| Output | Descripción |
|--------|-------------|
| dashboard_name | CloudWatch Dashboard name |
| dashboard_url | CloudWatch Dashboard URL |
| lambda_function_name | Health Checker Lambda name |
| lambda_function_arn | Health Checker Lambda ARN |
| alarms | Map con nombres de todas las alarmas |
