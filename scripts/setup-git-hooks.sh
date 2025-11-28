#!/bin/bash

#######################################################
# Script para configurar git hooks pre-push
# Ejecuta tests antes de permitir push
#######################################################

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}Configurando Git Hooks${NC}"
echo -e "${CYAN}======================================${NC}\n"

# Crear directorio de hooks si no existe
mkdir -p .git/hooks

# Crear pre-push hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

#######################################################
# Git Pre-Push Hook
# Ejecuta tests antes de permitir push
#######################################################

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\n${CYAN}======================================${NC}"
echo -e "${CYAN}Pre-Push Hook: Ejecutando Tests${NC}"
echo -e "${CYAN}======================================${NC}\n"

# Flag para controlar si hubo errores
ERRORS=0

# Función para ejecutar comando y capturar resultado
run_test() {
    local name=$1
    local cmd=$2

    echo -e "${YELLOW}Ejecutando: $name${NC}"

    if eval "$cmd"; then
        echo -e "${GREEN}✓ $name pasó${NC}\n"
    else
        echo -e "${RED}✗ $name falló${NC}\n"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. Python tests (product-service)
if [ -d "app/StockWiz/product-service/tests" ]; then
    run_test "Python Tests (Product Service)" \
        "cd app/StockWiz/product-service && pytest --cov=. --cov-report=term-missing -v && cd - > /dev/null"
fi

# 2. Go tests (api-gateway)
if [ -f "app/StockWiz/api-gateway/go.mod" ]; then
    run_test "Go Tests (API Gateway)" \
        "cd app/StockWiz/api-gateway && go test ./... -v && cd - > /dev/null"
fi

# 3. Go tests (inventory-service)
if [ -f "app/StockWiz/inventory-service/go.mod" ]; then
    run_test "Go Tests (Inventory Service)" \
        "cd app/StockWiz/inventory-service && go test ./... -v && cd - > /dev/null"
fi

# Resultados finales
echo -e "${CYAN}======================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Todos los tests pasaron${NC}"
    echo -e "${GREEN}✓ Push permitido${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    exit 0
else
    echo -e "${RED}✗ $ERRORS test(s) fallaron${NC}"
    echo -e "${RED}✗ Push bloqueado${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    echo -e "${YELLOW}Opciones:${NC}"
    echo -e "  1. Arregla los tests y vuelve a intentar"
    echo -e "  2. Skip hook: git push --no-verify (no recomendado)"
    echo ""
    exit 1
fi
EOF

# Hacer el hook ejecutable
chmod +x .git/hooks/pre-push

echo -e "${GREEN}✓ Git pre-push hook configurado${NC}"
echo -e "\n${YELLOW}¿Qué hace este hook?${NC}"
echo -e "  - Ejecuta tests de Python antes de cada push"
echo -e "  - Ejecuta tests de Go antes de cada push"
echo -e "  - Bloquea el push si algún test falla"
echo -e "\n${YELLOW}Para saltarte el hook (no recomendado):${NC}"
echo -e "  git push --no-verify"
echo -e "\n${CYAN}======================================${NC}\n"
