#!/bin/bash

# ============================================
# Diagnóstico de Monitoring y Alertas
# ============================================

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Diagnóstico de Monitoring - StockWiz${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo ""

LAMBDA_NAME="${ENVIRONMENT}-stockwiz-health-checker"
SNS_TOPIC_NAME="${ENVIRONMENT}-stockwiz-alerts"

# 1. Verificar Lambda
echo -e "${CYAN}[1/6] Verificando Lambda Function...${NC}"
if aws lambda get-function --function-name $LAMBDA_NAME --region $AWS_REGION &>/dev/null; then
    echo -e "${GREEN}✓ Lambda encontrada: $LAMBDA_NAME${NC}"

    # Ver última ejecución
    LAST_LOG=$(aws logs tail /aws/lambda/$LAMBDA_NAME --since 30m --region $AWS_REGION 2>/dev/null | tail -5)
    if [ -n "$LAST_LOG" ]; then
        echo -e "${GREEN}✓ Lambda tiene logs recientes (últimos 30 min)${NC}"
    else
        echo -e "${YELLOW}⚠ Lambda no tiene logs recientes${NC}"
        echo -e "${YELLOW}  Ejecuta: aws lambda invoke --function-name $LAMBDA_NAME response.json${NC}"
    fi
else
    echo -e "${RED}✗ Lambda NO encontrada: $LAMBDA_NAME${NC}"
    exit 1
fi

# 2. Verificar EventBridge Rule
echo -e "\n${CYAN}[2/6] Verificando EventBridge Rule...${NC}"
RULE_NAME="${ENVIRONMENT}-health-checker-schedule"
RULE_STATE=$(aws events describe-rule --name $RULE_NAME --region $AWS_REGION --query 'State' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$RULE_STATE" = "ENABLED" ]; then
    echo -e "${GREEN}✓ EventBridge Rule está HABILITADA${NC}"
    echo -e "${GREEN}  Lambda se ejecuta cada 5 minutos automáticamente${NC}"
elif [ "$RULE_STATE" = "DISABLED" ]; then
    echo -e "${RED}✗ EventBridge Rule está DESHABILITADA${NC}"
    echo -e "${YELLOW}  Habilítala con: aws events enable-rule --name $RULE_NAME${NC}"
else
    echo -e "${RED}✗ EventBridge Rule NO encontrada${NC}"
fi

# 3. Verificar métricas en CloudWatch
echo -e "\n${CYAN}[3/6] Verificando métricas en CloudWatch...${NC}"
METRICS_COUNT=$(aws cloudwatch list-metrics --namespace "StockWiz/$ENVIRONMENT" --region $AWS_REGION --query 'length(Metrics)' --output text 2>/dev/null || echo "0")

if [ "$METRICS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Encontradas $METRICS_COUNT métricas en CloudWatch${NC}"
    echo -e "${YELLOW}Métricas disponibles:${NC}"
    aws cloudwatch list-metrics \
        --namespace "StockWiz/$ENVIRONMENT" \
        --region $AWS_REGION \
        --query 'Metrics[*].MetricName' \
        --output text | tr '\t' '\n' | sort -u | head -10
else
    echo -e "${RED}✗ NO hay métricas en CloudWatch${NC}"
    echo -e "${YELLOW}Invocando Lambda para generar métricas...${NC}"
    aws lambda invoke --function-name $LAMBDA_NAME --region $AWS_REGION response.json &>/dev/null
    echo -e "${GREEN}✓ Lambda invocada. Espera 1 minuto y verifica nuevamente${NC}"
fi

# 4. Verificar SNS Topic
echo -e "\n${CYAN}[4/6] Verificando SNS Topic...${NC}"
SNS_ARN=$(aws sns list-topics --region $AWS_REGION --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')].TopicArn" --output text 2>/dev/null)

if [ -n "$SNS_ARN" ]; then
    echo -e "${GREEN}✓ SNS Topic encontrado${NC}"
    echo -e "  ARN: ${YELLOW}$SNS_ARN${NC}"

    # Verificar suscripciones
    SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn $SNS_ARN --region $AWS_REGION --query 'Subscriptions[*].[Protocol,Endpoint,SubscriptionArn]' --output text 2>/dev/null)

    if [ -n "$SUBSCRIPTIONS" ]; then
        echo -e "${GREEN}✓ Suscripciones encontradas:${NC}"
        echo "$SUBSCRIPTIONS" | while IFS=$'\t' read -r protocol endpoint sub_arn; do
            if [[ "$sub_arn" == *"PendingConfirmation"* ]]; then
                echo -e "  ${YELLOW}⚠ $protocol: $endpoint - PENDIENTE DE CONFIRMACIÓN${NC}"
                echo -e "    ${YELLOW}Revisa tu email y confirma la suscripción${NC}"
            else
                echo -e "  ${GREEN}✓ $protocol: $endpoint - CONFIRMADO${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠ No hay suscripciones configuradas${NC}"
    fi
else
    echo -e "${RED}✗ SNS Topic NO encontrado${NC}"
fi

# 5. Verificar alarmas
echo -e "\n${CYAN}[5/6] Verificando CloudWatch Alarms...${NC}"
ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix "$ENVIRONMENT-" --region $AWS_REGION --query 'MetricAlarms[*].[AlarmName,StateValue,ActionsEnabled]' --output text 2>/dev/null)

if [ -n "$ALARMS" ]; then
    echo -e "${GREEN}✓ Alarmas encontradas:${NC}"
    echo "$ALARMS" | while IFS=$'\t' read -r name state actions; do
        if [ "$actions" = "True" ]; then
            if [ "$state" = "OK" ]; then
                echo -e "  ${GREEN}✓ $name: $state (Actions: Enabled)${NC}"
            elif [ "$state" = "ALARM" ]; then
                echo -e "  ${RED}✗ $name: $state (Actions: Enabled)${NC}"
            else
                echo -e "  ${YELLOW}⚠ $name: $state (Actions: Enabled)${NC}"
            fi
        else
            echo -e "  ${RED}✗ $name: $state (Actions: DISABLED)${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠ No se encontraron alarmas${NC}"
fi

# 6. Verificar Dashboard
echo -e "\n${CYAN}[6/6] Verificando CloudWatch Dashboard...${NC}"
DASHBOARD_NAME="${ENVIRONMENT}-stockwiz-dashboard"
if aws cloudwatch get-dashboard --dashboard-name $DASHBOARD_NAME --region $AWS_REGION &>/dev/null; then
    echo -e "${GREEN}✓ Dashboard encontrado: $DASHBOARD_NAME${NC}"
    DASHBOARD_URL="https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$DASHBOARD_NAME"
    echo -e "  URL: ${YELLOW}$DASHBOARD_URL${NC}"
else
    echo -e "${RED}✗ Dashboard NO encontrado${NC}"
fi

# Resumen
echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}Resumen y Próximos Pasos${NC}"
echo -e "${CYAN}============================================${NC}"

echo -e "\n${YELLOW}Para generar alertas de prueba:${NC}"
echo -e "  ./scripts/test-cloudwatch-alerts.sh $ENVIRONMENT"

echo -e "\n${YELLOW}Para invocar Lambda manualmente:${NC}"
echo -e "  aws lambda invoke --function-name $LAMBDA_NAME response.json && cat response.json | jq ."

echo -e "\n${YELLOW}Para ver logs de Lambda en tiempo real:${NC}"
echo -e "  aws logs tail /aws/lambda/$LAMBDA_NAME --follow"

echo -e "\n${YELLOW}Para ver métricas:${NC}"
echo -e "  aws cloudwatch list-metrics --namespace 'StockWiz/$ENVIRONMENT'"

echo -e "\n${YELLOW}Para ver estado de alarmas:${NC}"
echo -e "  aws cloudwatch describe-alarms --alarm-name-prefix '$ENVIRONMENT-' --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table"

echo -e "\n${GREEN}✓ Diagnóstico completado${NC}"
