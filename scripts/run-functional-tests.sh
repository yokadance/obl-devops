#!/bin/bash

#######################################################
# Script para ejecutar tests funcionales de API
# con Newman (Postman CLI)
#######################################################

set -e

# Colores para output (un poco carolo pero lindo)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Vvcio

# Configuración
COLLECTION="tests/postman/StockWiz-API-Tests.postman_collection.json"
ENV_FILE="tests/postman/dev.postman_environment.json"
TEMP_ENV_FILE="/tmp/newman-env-$$.json"
REPORT_FILE="newman-report.html"

# Función para limpiar archivos temporales
cleanup() {
    if [ -f "$TEMP_ENV_FILE" ]; then
        rm -f "$TEMP_ENV_FILE"
    fi
}

trap cleanup EXIT

# Función para mostrar uso
show_usage() {
    echo -e "${CYAN}Uso:${NC}"
    echo "  $0 [OPTION]"
    echo ""
    echo "Opciones:"
    echo "  local         Ejecutar tests contra localhost:8080"
    echo "  dev           Ejecutar tests contra AWS Dev (requiere AWS CLI configurado)"
    echo "  custom URL    Ejecutar tests contra URL custom"
    echo "  -h, --help    Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 local"
    echo "  $0 dev"
    echo "  $0 custom http://my-alb.us-east-1.elb.amazonaws.com"
}

# Función para verificar Newman
check_newman() {
    if ! command -v newman &> /dev/null; then
        echo -e "${RED}❌ Newman no está instalado${NC}"
        echo -e "${YELLOW}Instalando Newman...${NC}"
        npm install -g newman newman-reporter-htmlextra
    else
        echo -e "${GREEN}✓ Newman encontrado${NC}"
    fi
}

# Función para ejecutar tests
run_tests() {
    local BASE_URL=$1

    echo -e "\n${CYAN}======================================${NC}"
    echo -e "${CYAN}Ejecutando Tests Funcionales${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo -e "${YELLOW}Base URL:${NC} $BASE_URL"
    echo ""

    # Crear environment file temporal con la URL correcta
    sed "s|http://localhost:8080|$BASE_URL|g" "$ENV_FILE" > "$TEMP_ENV_FILE"

    # Ejecutar Newman
    newman run "$COLLECTION" \
        -e "$TEMP_ENV_FILE" \
        --reporters cli,htmlextra \
        --reporter-htmlextra-export "$REPORT_FILE" \
        --color on \
        --disable-unicode

    local EXIT_CODE=$?

    echo ""
    echo -e "${CYAN}======================================${NC}"

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✅ Todos los tests pasaron exitosamente${NC}"
        echo -e "${CYAN}Reporte generado:${NC} $REPORT_FILE"

        # Abrir reporte automáticamente si es posible
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Abriendo reporte...${NC}"
            open "$REPORT_FILE"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v xdg-open &> /dev/null; then
                echo -e "${YELLOW}Abriendo reporte...${NC}"
                xdg-open "$REPORT_FILE"
            fi
        fi
    else
        echo -e "${RED}❌ Algunos tests fallaron${NC}"
        echo -e "${CYAN}Revisa el reporte para más detalles:${NC} $REPORT_FILE"
    fi

    echo -e "${CYAN}======================================${NC}\n"

    return $EXIT_CODE
}

# Función para obtener ALB DNS de AWS
get_alb_dns() {
    local ENV=$1

    echo -e "${YELLOW}Obteniendo ALB DNS de AWS...${NC}"

    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI no está instalado${NC}"
        exit 1
    fi

    local ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names "${ENV}-stockwiz-alb" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null)

    if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" == "None" ]; then
        echo -e "${RED}❌ No se pudo obtener el DNS del ALB${NC}"
        echo -e "${YELLOW}Verifica que:${NC}"
        echo "  1. AWS CLI esté configurado correctamente"
        echo "  2. El ALB '${ENV}-stockwiz-alb' exista"
        echo "  3. Tengas permisos para acceder al ALB"
        exit 1
    fi

    echo -e "${GREEN}✓ ALB encontrado:${NC} $ALB_DNS"
    echo "http://$ALB_DNS"
}

# Función para verificar que los servicios estén disponibles
check_health() {
    local BASE_URL=$1

    echo -e "${YELLOW}Verificando que los servicios estén disponibles...${NC}"

    local MAX_RETRIES=3
    local RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -f -s "${BASE_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Servicios están disponibles${NC}"
            return 0
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Reintentando... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
            sleep 3
        fi
    done

    echo -e "${RED}⚠️  No se pudo conectar a los servicios${NC}"
    echo -e "${YELLOW}Los tests pueden fallar. ¿Continuar de todas formas? (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# Procesar argumentos
case "${1:-}" in
    local)
        check_newman
        BASE_URL="http://localhost:8080"
        check_health "$BASE_URL"
        run_tests "$BASE_URL"
        ;;
    dev)
        check_newman
        ALB_DNS=$(get_alb_dns "dev")
        BASE_URL="http://$ALB_DNS"
        check_health "$BASE_URL"
        run_tests "$BASE_URL"
        ;;
    custom)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}❌ Debes especificar una URL${NC}"
            show_usage
            exit 1
        fi
        check_newman
        BASE_URL="$2"
        check_health "$BASE_URL"
        run_tests "$BASE_URL"
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    "")
        echo -e "${RED}❌ Debes especificar una opción${NC}\n"
        show_usage
        exit 1
        ;;
    *)
        echo -e "${RED}❌ Opción inválida: $1${NC}\n"
        show_usage
        exit 1
        ;;
esac
