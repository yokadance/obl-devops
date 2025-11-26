#!/bin/bash

# ============================================
# Script de prueba para CloudWatch Alerts
# ============================================
# Este script permite probar alertas de CloudWatch
# en tiempo real simulando diferentes fallas
#
# Uso:
#   ./scripts/test-cloudwatch-alerts.sh [environment] [failure_type]
#
# Parámetros:
#   environment: dev
#   failure_type: database

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
FAILURE_TYPE=${2:-database}
AWS_REGION=${AWS_REGION:-us-east-1}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}CloudWatch Alerts - Prueba en Tiempo Real${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Tipo de falla: ${YELLOW}$FAILURE_TYPE${NC}"
echo ""

LAMBDA_NAME="${ENVIRONMENT}-stockwiz-health-checker"

echo -e "${YELLOW}Pruebas disponibles:${NC}"
echo ""
echo -e "${GREEN}1. Simular falla de health check (Lambda)${NC}"
echo "   - Envia metrica con health = 0"
echo "   - Alarma se activa en ~5-10 minutos"
echo ""
echo -e "${GREEN}2. Simular alto CPU/Memory${NC}"
echo "   - Envia metricas con valores altos"
echo "   - Alarma se activa en ~5-10 minutos"
echo ""
echo -e "${GREEN}3. Parar servicio ECS (DESTRUCTIVO)${NC}"
echo "   - Para el servicio ECS real"
echo "   - Genera alertas reales"
echo "   - ⚠️  Causa downtime real"
echo ""

read -p "Selecciona tipo de prueba (1-3): " TEST_TYPE

case $TEST_TYPE in
    1)
        echo -e "\n${CYAN}[Prueba 1] Simulando falla de health check...${NC}"

        # Crear payload JSON para Lambda
        PAYLOAD=$(cat <<EOF
{
  "simulate_failure": true,
  "failure_type": "${FAILURE_TYPE}"
}
EOF
)

        echo -e "${YELLOW}Invocando Lambda con simulacion de falla...${NC}"

        # Guardar payload en archivo temporal
        PAYLOAD_FILE=$(mktemp)
        echo "$PAYLOAD" > "$PAYLOAD_FILE"

        aws lambda invoke \
            --function-name $LAMBDA_NAME \
            --region $AWS_REGION \
            --cli-binary-format raw-in-base64-out \
            --payload "file://$PAYLOAD_FILE" \
            response.json

        # Limpiar archivo temporal
        rm -f "$PAYLOAD_FILE"

        echo -e "\n${GREEN}✓ Lambda invocada${NC}"
        echo -e "${YELLOW}Respuesta:${NC}"
        cat response.json | jq . || cat response.json

        echo -e "\n${CYAN}Para generar mas datos de falla, ejecuta:${NC}"
        echo -e "${YELLOW}./scripts/test-cloudwatch-alerts.sh $ENVIRONMENT $FAILURE_TYPE${NC}"

        echo -e "\n${CYAN}¿Qué sucedió?${NC}"
        echo "✓ Se enviaron métricas de falla para los últimos 15 minutos (4 períodos)"
        echo "✓ Esto genera suficientes datos para activar alarmas que requieren 2+ períodos"
        echo ""
        echo -e "${CYAN}Siguiente paso:${NC}"
        echo "1. ${GREEN}Espera 1-2 minutos${NC} (CloudWatch procesa las métricas)"
        echo "2. Ve al dashboard de CloudWatch:"
        echo "   ${YELLOW}make report ENV=$ENVIRONMENT${NC}"
        echo "   o abre: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$ENVIRONMENT-stockwiz-dashboard"
        echo "3. Verifica las alarmas (deberían activarse pronto):"
        echo "   ${YELLOW}aws cloudwatch describe-alarms --alarm-name-prefix \"$ENVIRONMENT-\" --region $AWS_REGION --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table${NC}"
        ;;

    2)
        echo -e "\n${CYAN}[Prueba 2] Simulando alto CPU/Memory...${NC}"
        echo -e "${YELLOW}Enviando métricas para los últimos 15 minutos (garantiza activación de alarma)...${NC}"
        echo ""

        # Enviar métricas para múltiples timestamps (últimos 15 minutos)
        # Esto garantiza 2+ períodos consecutivos de 5 minutos con valores altos
        for MINUTES_AGO in 15 10 5 0; do
            # Calcular timestamp en formato ISO8601
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                TIMESTAMP=$(date -u -v-${MINUTES_AGO}M +"%Y-%m-%dT%H:%M:%S")
            else
                # Linux
                TIMESTAMP=$(date -u -d "${MINUTES_AGO} minutes ago" +"%Y-%m-%dT%H:%M:%S")
            fi

            echo -e "${CYAN}→ Enviando métricas para timestamp: $TIMESTAMP (hace $MINUTES_AGO min)${NC}"

            # CPU alto
            aws cloudwatch put-metric-data \
                --namespace "AWS/ECS" \
                --metric-name CPUUtilization \
                --value 95 \
                --unit Percent \
                --timestamp $TIMESTAMP \
                --dimensions ClusterName=${ENVIRONMENT}-cluster \
                --region $AWS_REGION

            # Memory alto
            aws cloudwatch put-metric-data \
                --namespace "AWS/ECS" \
                --metric-name MemoryUtilization \
                --value 95 \
                --unit Percent \
                --timestamp $TIMESTAMP \
                --dimensions ClusterName=${ENVIRONMENT}-cluster \
                --region $AWS_REGION
        done

        echo -e "\n${GREEN}✓ Métricas enviadas para 4 períodos de tiempo${NC}"
        echo -e "${CYAN}Esto cubre los últimos 15 minutos, garantizando 2+ períodos consecutivos${NC}"
        echo ""
        echo -e "${CYAN}Las alarmas deberían activarse en 1-2 minutos${NC}"
        ;;

    3)
        echo -e "\n${RED}[Prueba 3] ⚠️  ADVERTENCIA: Esta prueba causa DOWNTIME REAL${NC}"
        read -p "¿Estás seguro? Esto parará el servicio ECS. [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelado."
            exit 0
        fi

        CLUSTER_NAME="${ENVIRONMENT}-cluster"
        SERVICE_NAME="${ENVIRONMENT}-stockwiz"

        echo -e "\n${YELLOW}Parando servicio ECS...${NC}"
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --desired-count 0 \
            --region $AWS_REGION

        echo -e "\n${GREEN}✓ Servicio detenido${NC}"
        echo -e "${RED}El servicio está CAIDO. Las alarmas se activarán pronto.${NC}"
        echo ""
        echo -e "${CYAN}Para restaurar el servicio:${NC}"
        echo -e "${YELLOW}aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 1 --region $AWS_REGION${NC}"
        echo ""
        echo -e "${CYAN}O usa:${NC}"
        echo -e "${YELLOW}make deploy-ecs ENV=$ENVIRONMENT${NC}"
        ;;

    *)
        echo -e "${RED}Opcion invalida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Monitoreo de Alarmas${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}Ver estado de alarmas:${NC}"
echo "  aws cloudwatch describe-alarms --alarm-name-prefix \"$ENVIRONMENT-\" --region $AWS_REGION --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table"
echo ""
echo -e "${YELLOW}Ver dashboard:${NC}"
echo "  make report ENV=$ENVIRONMENT"
echo ""
echo -e "${YELLOW}Ver logs de Lambda:${NC}"
echo "  aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $AWS_REGION"
echo ""
echo -e "${GREEN}✓ Prueba iniciada!${NC}"
