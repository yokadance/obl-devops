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

# Crear pre-push hook usando Docker
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

#######################################################
# Git Pre-Push Hook
# Ejecuta tests usando Docker (requiere poder iniciar los contenedores de forma local)
#######################################################

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\n${CYAN}======================================${NC}"
echo -e "${CYAN}Pre-Push Hook: Ejecutando Tests${NC}"
echo -e "${CYAN}(Localmente)${NC}"
echo -e "${CYAN}======================================${NC}\n"

# Verificar que Docker esté disponible
if ! command -v docker &> /dev/null; then
    echo -e "${RED}⚠️  Docker no está disponible${NC}"
    echo -e "${YELLOW}Puedes:${NC}"
    echo -e "  1. Instalar Docker y volver a intentar"
    echo -e "  2. Skip hook: git push --no-verify"
    echo ""
    exit 1
fi

# Ejecutar script de tests con Docker
./scripts/run-tests-docker.sh

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Push permitido${NC}\n"
    exit 0
else
    echo -e "${RED}✗ Push bloqueado${NC}"
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
