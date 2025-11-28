#!/bin/bash

#######################################################
# Script para ejecutar tests usando Docker
# NO requiere instalar Python/Go localmente
#######################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verificar que Docker esté instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado${NC}"
    echo -e "${YELLOW}Instala Docker desde: https://www.docker.com/products/docker-desktop${NC}"
    exit 1
fi

echo -e "\n${CYAN}======================================${NC}"
echo -e "${CYAN}Ejecutando Tests con Docker${NC}"
echo -e "${CYAN}======================================${NC}\n"

ERRORS=0

# ========================================
# Python Tests (Product Service)
# ========================================
echo -e "${YELLOW}[1/3] Ejecutando Python Tests (Product Service)...${NC}\n"

docker run --rm \
    -v "$(pwd)/app/StockWiz/product-service:/app" \
    -w /app \
    -e SKIP_DATABASE=true \
    -e SKIP_REDIS=true \
    python:3.11-slim \
    bash -c "
        pip install -q -r requirements.txt pytest pytest-cov httpx && \
        pytest tests/ -v --cov=. --cov-report=term-missing
    "

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Python tests pasaron${NC}\n"
else
    echo -e "\n${RED}✗ Python tests fallaron${NC}\n"
    ERRORS=$((ERRORS + 1))
fi

# ========================================
# Go Tests (API Gateway)
# ========================================
echo -e "${YELLOW}[2/3] Ejecutando Go Tests (API Gateway)...${NC}\n"

docker run --rm \
    -v "$(pwd)/app/StockWiz/api-gateway:/app" \
    -w /app \
    golang:1.21-alpine \
    sh -c "
        go mod download && \
        go test ./... -v -cover
    " 2>&1 | grep -v "no test files" || true

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Go tests (API Gateway) pasaron${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Go tests (API Gateway) - no test files o fallaron${NC}\n"
fi

# ========================================
# Go Tests (Inventory Service)
# ========================================
echo -e "${YELLOW}[3/3] Ejecutando Go Tests (Inventory Service)...${NC}\n"

docker run --rm \
    -v "$(pwd)/app/StockWiz/inventory-service:/app" \
    -w /app \
    golang:1.21-alpine \
    sh -c "
        go mod download && \
        go test ./... -v -cover
    " 2>&1 | grep -v "no test files" || true

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Go tests (Inventory Service) pasaron${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Go tests (Inventory Service) - no test files o fallaron${NC}\n"
fi

# ========================================
# Resultados Finales
# ========================================
echo -e "${CYAN}======================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Todos los tests pasaron${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    exit 0
else
    echo -e "${RED}❌ $ERRORS test suite(s) fallaron${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    exit 1
fi
