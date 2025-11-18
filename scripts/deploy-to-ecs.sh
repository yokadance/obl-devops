#!/bin/bash

# ============================================
# Deploy to ECS - Force Update Services
# ============================================
# Este script fuerza la actualización de los servicios ECS
# para que usen las últimas imágenes de ECR
#
# Uso:
#   ./scripts/deploy-to-ecs.sh [environment] [service]
#
# Parámetros:
#   environment: dev, stage, prod (default: dev)
#   service: api-gateway, product-service, inventory-service, all (default: all)
#
# Ejemplos:
#   ./scripts/deploy-to-ecs.sh dev all
#   ./scripts/deploy-to-ecs.sh dev api-gateway
#   ./scripts/deploy-to-ecs.sh prod product-service

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración por defecto
ENVIRONMENT=${1:-dev}
SERVICE=${2:-all}
AWS_REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME="${ENVIRONMENT}-cluster"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploy to ECS - StockWiz${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Service(s): ${YELLOW}$SERVICE${NC}"
echo -e "Cluster: ${YELLOW}$CLUSTER_NAME${NC}"
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo ""

# Función para forzar actualización de un servicio
force_new_deployment() {
    local service_name=$1
    local ecs_service_name="${ENVIRONMENT}-${service_name}"

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Desplegando: $service_name${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}Verificando que el servicio existe...${NC}"

    # Verificar si el servicio existe
    if ! aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $ecs_service_name \
        --region $AWS_REGION \
        --query 'services[0].serviceName' \
        --output text 2>/dev/null | grep -q "$ecs_service_name"; then
        echo -e "${RED}Error: El servicio $ecs_service_name no existe en el cluster $CLUSTER_NAME${NC}"
        return 1
    fi

    echo -e "${GREEN}Servicio encontrado${NC}"

    # Forzar nuevo despliegue
    echo -e "\n${YELLOW}Forzando nuevo despliegue...${NC}"
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $ecs_service_name \
        --force-new-deployment \
        --region $AWS_REGION \
        --no-cli-pager > /dev/null

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Fallo el despliegue de $service_name${NC}"
        return 1
    fi

    echo -e "${GREEN}Despliegue iniciado exitosamente${NC}"

    # Esperar a que el servicio se estabilice (opcional)
    echo -e "\n${YELLOW}Esperando a que el servicio se estabilice...${NC}"
    echo -e "${YELLOW}Esto puede tomar varios minutos...${NC}"

    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $ecs_service_name \
        --region $AWS_REGION

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Servicio estabilizado exitosamente${NC}"

        # Mostrar información del servicio
        echo -e "\n${YELLOW}Estado del servicio:${NC}"
        aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $ecs_service_name \
            --region $AWS_REGION \
            --query 'services[0].{RunningCount:runningCount,DesiredCount:desiredCount,Status:status,TaskDefinition:taskDefinition}' \
            --output table
    else
        echo -e "${YELLOW}Advertencia: El servicio no se estabilizó en el tiempo esperado${NC}"
        echo -e "${YELLOW}Puedes verificar el estado en la consola de AWS${NC}"
    fi

    return 0
}

# Procesar servicios según el parámetro
deploy_service() {
    case $1 in
        api-gateway|product-service|inventory-service|all|stockwiz)
            # Ahora todos los servicios están en una sola task definition unificada
            force_new_deployment "stockwiz"
            ;;
        *)
            echo -e "${RED}Error: Servicio desconocido '$1'${NC}"
            echo "Servicios válidos: stockwiz, all"
            exit 1
            ;;
    esac
}

# Ejecutar
deploy_service $SERVICE

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Despliegue completado${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Puedes verificar el estado de tus servicios con:${NC}"
echo -e "aws ecs list-services --cluster $CLUSTER_NAME --region $AWS_REGION"
echo -e "\n${YELLOW}O acceder a la aplicación a través del ALB:${NC}"
echo -e "cd IaC/terraform/environments/$ENVIRONMENT && terraform output alb_dns_name"
