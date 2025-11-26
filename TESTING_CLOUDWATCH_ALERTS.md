# Testing CloudWatch Alerts - Guía Completa

Esta guía te muestra cómo probar las alertas de CloudWatch en tiempo real. Todo esta demostrado para el enviroment de dev, puede ser aplicado a cualquier otro.

## 🎯 Objetivo

Simular una falla (por ejemplo, base de datos caída) y recibir una alerta de CloudWatch en tiempo real.

## 📋 Prerrequisitos

1. AWS CLI configurado
2. Infraestructura desplegada con módulo de monitoring
3. (Opcional) Email configurado para recibir notificaciones

## 🔧 Setup Inicial

###⚠️ ATENCION si ya corriste el comando[ make setup-and-deploy ENV=dev ] que crea la infra y hace el deploy debes obviar este punto inicial

### 1. Aplicar módulo de monitoring si no has ejecutado el script de build and deploy  [ make setup-and-deploy ENV=dev ]



```bash
terraform -chdir=IaC/terraform/environments/dev apply
```

### 2. (Opcional) Configurar email para notificaciones

Editar el archivo `IaC/terraform/environments/dev/main.tf`:

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

Luego tenemos que aplicar los cambios:

```bash
terraform -chdir=IaC/terraform/environments/dev apply
```

**IMPORTANTE**: Si has configurado envio de email, debes confirmar la suscripción del email en tu bandeja de entrada.

## 🧪 Pruebas Disponibles

### Prueba 1: Simular Falla de Health Check (RECOMENDADO)

Esta es la forma más segura de probar. No causa downtime real.

```bash
./scripts/test-cloudwatch-alerts.sh dev database
```

Selecciona opción `1` cuando se te pregunte.

**Qué hace esto?:**
- Invoca la Lambda con un flag especial
- La Lambda envía métricas de falla para **los últimos 15 minutos** (4 períodos de datos)
- Esto genera  datos para activar alarmas que requieren 2+ períodos consecutivos
- CloudWatch detecta las métricas malas

**Monitorear:**
##Si queremos monitorear sin entrar al dashboard creado, podemos usar los siguientes comandos.

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

**Qué haceesto?:**
- Envía métricas de CPU/Memory al 95%
- Alarmas de CPU/Memory se activan
- No causa impacto real en el servicio

### Prueba 3: Parar Servicio ECS (⚠️ baja el deploy)

**ADVERTENCIA**: Esto causa downtime real. 

```bash
./scripts/test-cloudwatch-alerts.sh dev database
```

Selecciona opción `3`.

**Qué hace:**
- Para el servicio ECS real
- Todas las alarmas se activarian
- El servicio queda inaccesible

**Restaurar lo detenido debemos usar los siguientes comanditos:**

```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-stockwiz \
  --desired-count 1
```


## 🔍 Comandos Útiles

### Ver todas las alarmas

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix "dev-" \
  --region us-east-1
```

### Ver métricas de health check

```bash
aws cloudwatch get-metric-statistics \
  --namespace "StockWiz/dev" \
  --metric-name "HealthCheck-HTTP" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Resetear alarma manualmente

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "dev-health-check-http-failed" \
  --state-value OK \
  --state-reason "Manual reset for testing"
```

### Invocar Lambda manualmente con falla simulada

```bash
aws lambda invoke \
  --function-name dev-stockwiz-health-checker \
  --payload '{"simulate_failure":true,"failure_type":"database"}' \
  response.json

cat response.json | jq .
```

## 📧 Configurar Múltiples Emails

Si quieres que múltiples personas reciban alertas:

1. Ve a la consola de SNS: https://console.aws.amazon.com/sns
2. Busca el topic: `dev-stockwiz-alerts`
3. Click en "Create subscription"
4. Protocol: Email
5. Endpoint: otro-email@example.com
6. Confirma el email

## 🎓 Explicación Técnica

### ¿Cómo funcionan las alarmas?

1. **Lambda ejecuta cada 5 minutos** (EventBridge)
2. **Lambda hace health checks** a los endpoints
3. **Lambda envía métricas** a CloudWatch
4. **CloudWatch evalúa métricas** cada 5 minutos
5. **Si condición se cumple por 2 periodos** (10 min), alarma se activa
6. **SNS envía notificación** al email configurado

### Estados de alarma

- **OK**: Todo funciona correctamente
- **ALARM**: Condición de alarma cumplida
- **INSUFFICIENT_DATA**: No hay suficientes datos para evaluar


## 🐛 Troubleshooting

### No recibo emails

1. Verifica que confirmaste la suscripción de email
2. Revisa spam/junk
3. Verifica el topic SNS:
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:dev-stockwiz-alerts
```

## 📚 Referencias

- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [SNS Email Notifications](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html)
- [Lambda Metrics](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-metrics.html)
