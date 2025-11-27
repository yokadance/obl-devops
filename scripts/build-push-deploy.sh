#!/bin/bash

# ============================================
# Build, Push y Deploy completo a ECS
# ============================================
# Este script ejecuta todo el proceso:
# 1. Build de las imágenes Docker
# 2. Push a ECR
# 3. Deploy a ECS
#
# Uso:
#   ./scripts/build-push-deploy.sh [environment] [service]
#
# Parámetros:
#   environment: dev, stage, prod (default: dev)
#   service: api-gateway, product-service, inventory-service, all (default: all)
#
# Ejemplos:
#   ./scripts/build-push-deploy.sh dev all
#   ./scripts/build-push-deploy.sh dev api-gateway

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-dev}
SERVICE=${2:-all}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Build, Push y Deploy - StockWiz${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Service(s): ${YELLOW}$SERVICE${NC}"
echo ""

# Paso 1: Build y Push a ECR
echo -e "${GREEN}[1/2] Building y pusheando imágenes a ECR...${NC}"
./scripts/build-and-push-ecr.sh $ENVIRONMENT $SERVICE

if [ $? -ne 0 ]; then
    echo -e "${RED}Error en el build/push. Abortando...${NC}"
    exit 1
fi

echo -e "\n${GREEN}Build y push completados exitosamente${NC}"

# Pequeña pausa para asegurar que las imágenes están disponibles
echo -e "\n${YELLOW}Esperando 5 segundos para asegurar disponibilidad de imágenes...${NC}"
sleep 5

# Paso 2: Deploy a ECS
echo -e "\n${GREEN}[2/2] Desplegando a ECS...${NC}"
./scripts/deploy-to-ecs.sh $ENVIRONMENT $SERVICE

if [ $? -ne 0 ]; then
    echo -e "${RED}Error en el deploy. Verifica los logs de ECS.${NC}"
    exit 1
fi

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}Proceso completado exitosamente${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "\n${GREEN}Tus servicios han sido actualizados con las últimas imágenes${NC}"

# Generar reporte HTML y abrirlo en el navegador
echo -e "\n${CYAN}Generando reporte de despliegue...${NC}"
./scripts/generate-deployment-report.sh $ENVIRONMENT
