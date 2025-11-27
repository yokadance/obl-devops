#!/bin/bash

# ============================================
# Setup Terraform Backend S3
# ============================================
# Este script configura automáticamente el backend S3 de Terraform
# usando el AWS Account ID del usuario actual
#
# Uso:
#   ./scripts/setup-terraform-backend.sh
#
# Lo que hace:
#   1. Obtiene tu AWS Account ID
#   2. Crea el bucket S3 si no existe
#   3. Configura versionado y encriptación
#   4. Actualiza los archivos main.tf con el bucket correcto

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Setup Terraform Backend S3${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Obtener AWS Account ID
echo -e "${YELLOW}Obteniendo AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: No se pudo obtener el AWS Account ID${NC}"
    echo -e "${RED}Asegúrate de tener AWS CLI configurado correctamente${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"

# Definir nombre del bucket
BUCKET_NAME="stockwiz-terraform-state-${AWS_ACCOUNT_ID}"
AWS_REGION="us-east-1"

echo -e "\n${YELLOW}Bucket S3: ${BUCKET_NAME}${NC}"
echo -e "${YELLOW}Region: ${AWS_REGION}${NC}"
echo ""

# Verificar si el bucket ya existe
echo -e "${YELLOW}Verificando si el bucket existe...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓ El bucket ya existe${NC}"
else
    echo -e "${YELLOW}El bucket no existe. Creando...${NC}"

    # Crear bucket
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION"

    echo -e "${GREEN}✓ Bucket creado${NC}"
fi

# Habilitar versionado
echo -e "\n${YELLOW}Habilitando versionado...${NC}"
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo -e "${GREEN}✓ Versionado habilitado${NC}"

# Habilitar encriptación
echo -e "\n${YELLOW}Habilitando encriptación...${NC}"
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

echo -e "${GREEN}✓ Encriptación habilitada${NC}"

# Actualizar archivos main.tf
echo -e "\n${YELLOW}Actualizando archivos de configuración...${NC}"

ENVIRONMENTS=("dev" "stage" "prod")

for ENV in "${ENVIRONMENTS[@]}"; do
    MAIN_TF="IaC/terraform/environments/${ENV}/main.tf"

    if [ -f "$MAIN_TF" ]; then
        echo -e "${CYAN}  Actualizando ${ENV}...${NC}"

        # Usar sed para reemplazar el bucket name
        # macOS usa sed -i '' mientras que Linux usa sed -i
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/bucket *= *\"stockwiz-terraform-state-[0-9]*\"/bucket  = \"${BUCKET_NAME}\"/" "$MAIN_TF"
        else
            sed -i "s/bucket *= *\"stockwiz-terraform-state-[0-9]*\"/bucket  = \"${BUCKET_NAME}\"/" "$MAIN_TF"
        fi

        echo -e "${GREEN}  ✓ ${ENV} actualizado${NC}"
    else
        echo -e "${YELLOW}  ⚠ ${MAIN_TF} no encontrado${NC}"
    fi
done

echo -e "\n${CYAN}============================================${NC}"
echo -e "${CYAN}Configuración completada${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${GREEN}Tu backend S3 está configurado:${NC}"
echo -e "  Bucket: ${BUCKET_NAME}"
echo -e "  Region: ${AWS_REGION}"
echo -e "  Versionado: Habilitado"
echo -e "  Encriptación: Habilitada"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  1. Revisa los cambios en los archivos main.tf"
echo -e "  2. Ejecuta: ${CYAN}git diff IaC/terraform/environments/*/main.tf${NC}"
echo -e "  3. Si todo se ve bien, puedes hacer commit de los cambios"
echo -e "  4. Ejecuta: ${CYAN}make setup-and-deploy ENV=dev${NC}"
echo ""
