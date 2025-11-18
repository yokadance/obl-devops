#!/bin/bash

# ============================================
# Build and Push Docker Images to ECR
# ============================================
# Este script construye las imágenes Docker de los servicios
# de StockWiz y las sube a Amazon ECR
#
# Uso:
#   ./scripts/build-and-push-ecr.sh [environment] [service]
#
# Parámetros:
#   environment: dev, stage, prod (default: dev)
#   service: api-gateway, product-service, inventory-service, all (default: all)
#
# Ejemplos:
#   ./scripts/build-and-push-ecr.sh dev all
#   ./scripts/build-and-push-ecr.sh dev api-gateway
#   ./scripts/build-and-push-ecr.sh prod product-service

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración por defecto
ENVIRONMENT=${1:-dev}
SERVICE=${2:-all}
AWS_REGION=${AWS_REGION:-us-east-1}
APP_DIR="app/StockWiz"

# Verificar que estamos en el directorio raíz del proyecto[pues tenemos una estrucutura acorde a lo que estamos trabajando y no a un poryecto de TF]
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: No se encuentra el directorio $APP_DIR${NC}"
    echo "Ejecuta este script desde el directorio raíz del proyecto"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build and Push to ECR - StockWiz${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Service(s): ${YELLOW}$SERVICE${NC}"
echo -e "Region: ${YELLOW}$AWS_REGION${NC}"
echo ""

# Obtener Account ID de AWS
echo -e "${YELLOW}Obteniendo AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: No se pudo obtener el AWS Account ID${NC}"
    echo "Verifica que tus credenciales de AWS estén configuradas correctamente"
    exit 1
fi

echo -e "${GREEN}AWS Account ID: $AWS_ACCOUNT_ID${NC}"

# Login a ECR
echo -e "\n${YELLOW}Autenticando con ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Fallo la autenticación con ECR${NC}"
    exit 1
fi

echo -e "${GREEN}Autenticación exitosa${NC}"

# Función para build y push de un servicio
build_and_push() {
    local service_name=$1
    local service_dir=$2

    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Procesando: $service_name${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Nombre del repositorio en ECR
    local ecr_repo_name="${ENVIRONMENT}-stockwiz-${service_name}"
    local ecr_url="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ecr_repo_name"

    # Tag con timestamp para versioning
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local git_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
    local image_tag="${timestamp}-${git_hash}"

    echo -e "${YELLOW}Repositorio ECR: $ecr_repo_name${NC}"
    echo -e "${YELLOW}Tag: $image_tag${NC}"

    # Verificar que existe el Dockerfile
    if [ ! -f "$APP_DIR/$service_dir/Dockerfile" ]; then
        echo -e "${RED}Error: No se encuentra Dockerfile en $APP_DIR/$service_dir${NC}"
        return 1
    fi

    # Build de la imagen
    echo -e "\n${YELLOW}Building Docker image...${NC}"
    docker build --platform linux/amd64 -t $service_name:latest -t $service_name:$image_tag $APP_DIR/$service_dir

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Fallo el build de $service_name${NC}"
        return 1
    fi

    echo -e "${GREEN}Build exitoso${NC}"

    # Tag para ECR
    echo -e "\n${YELLOW}Tagging images for ECR...${NC}"
    docker tag $service_name:latest $ecr_url:latest
    docker tag $service_name:$image_tag $ecr_url:$image_tag

    # Push a ECR
    echo -e "\n${YELLOW}Pushing to ECR...${NC}"
    docker push $ecr_url:latest
    docker push $ecr_url:$image_tag

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Fallo el push de $service_name${NC}"
        return 1
    fi

    echo -e "${GREEN}Push exitoso${NC}"
    echo -e "${GREEN}Imagen disponible en:${NC}"
    echo -e "  ${YELLOW}$ecr_url:latest${NC}"
    echo -e "  ${YELLOW}$ecr_url:$image_tag${NC}"

    return 0
}

# Procesar servicios según el parámetro
process_service() {
    case $1 in
        api-gateway)
            build_and_push "api-gateway" "api-gateway"
            ;;
        product-service)
            build_and_push "product-service" "product-service"
            ;;
        inventory-service)
            build_and_push "inventory-service" "inventory-service"
            ;;
        all)
            build_and_push "api-gateway" "api-gateway"
            build_and_push "product-service" "product-service"
            build_and_push "inventory-service" "inventory-service"
            ;;
        *)
            echo -e "${RED}Error: Servicio desconocido '$1'${NC}"
            echo "Servicios válidos: api-gateway, product-service, inventory-service, all"
            exit 1
            ;;
    esac
}

# Ejecutar
process_service $SERVICE

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Proceso completado exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
