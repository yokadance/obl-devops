#!/bin/bash

# Script para construir y pushear imágenes Docker a ECR
# Uso: ./build-and-push.sh [environment] [tag]
# Ejemplo: ./build-and-push.sh dev latest

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
ENVIRONMENT=${1:-dev}
TAG=${2:-latest}
AWS_REGION=${AWS_REGION:-us-east-1}
APP_DIR="app/StockWiz"

# Verificar que estamos en el directorio correcto
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: No se encontró el directorio $APP_DIR${NC}"
    echo "Ejecuta este script desde la raíz del proyecto"
    exit 1
fi

# Obtener AWS Account ID
echo -e "${YELLOW}Obteniendo AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: No se pudo obtener el AWS Account ID. Verifica tus credenciales de AWS.${NC}"
    exit 1
fi

echo -e "${GREEN}AWS Account ID: $AWS_ACCOUNT_ID${NC}"

# Construir nombres de repositorios ECR
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
API_GATEWAY_REPO="${ECR_BASE}/${ENVIRONMENT}-stockwiz-api-gateway"
PRODUCT_SERVICE_REPO="${ECR_BASE}/${ENVIRONMENT}-stockwiz-product-service"
INVENTORY_SERVICE_REPO="${ECR_BASE}/${ENVIRONMENT}-stockwiz-inventory-service"

echo -e "${YELLOW}Repositorios ECR:${NC}"
echo "  API Gateway: $API_GATEWAY_REPO"
echo "  Product Service: $PRODUCT_SERVICE_REPO"
echo "  Inventory Service: $INVENTORY_SERVICE_REPO"
echo ""

# Login a ECR
echo -e "${YELLOW}Haciendo login a ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_BASE

# Función para build y push
build_and_push() {
    local SERVICE_NAME=$1
    local REPO_URL=$2
    local DOCKERFILE_PATH=$3
    local CONTEXT_PATH=$4
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Construyendo $SERVICE_NAME...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # Build de la imagen
    docker build -t ${SERVICE_NAME}:${TAG} -f ${DOCKERFILE_PATH} ${CONTEXT_PATH}
    
    # Tag para ECR
    docker tag ${SERVICE_NAME}:${TAG} ${REPO_URL}:${TAG}
    
    # Push a ECR
    echo -e "${YELLOW}Pusheando ${SERVICE_NAME} a ECR...${NC}"
    docker push ${REPO_URL}:${TAG}
    
    echo -e "${GREEN}✓ ${SERVICE_NAME} pusheado exitosamente${NC}"
    echo ""
}

# Build y push de cada servicio
build_and_push "api-gateway" "$API_GATEWAY_REPO" "$APP_DIR/api-gateway/Dockerfile" "$APP_DIR/api-gateway"
build_and_push "product-service" "$PRODUCT_SERVICE_REPO" "$APP_DIR/product-service/Dockerfile" "$APP_DIR/product-service"
build_and_push "inventory-service" "$INVENTORY_SERVICE_REPO" "$APP_DIR/inventory-service/Dockerfile" "$APP_DIR/inventory-service"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Todas las imágenes fueron pusheadas exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Imágenes disponibles en:"
echo "  - $API_GATEWAY_REPO:$TAG"
echo "  - $PRODUCT_SERVICE_REPO:$TAG"
echo "  - $INVENTORY_SERVICE_REPO:$TAG"


