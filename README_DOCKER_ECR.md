# Guía de Build y Push de Imágenes Docker a ECR

Esta guía explica cómo construir y pushear las imágenes Docker de StockWiz a Amazon ECR.

## Prerrequisitos

1. **AWS CLI configurado** con credenciales válidas
2. **Docker instalado** y funcionando
3. **Terraform aplicado** para crear los repositorios ECR
4. **Permisos AWS** necesarios:
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:GetDownloadUrlForLayer`
   - `ecr:BatchGetImage`
   - `ecr:PutImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`

## Paso 1: Crear Repositorios ECR con Terraform

Primero, asegúrate de que los repositorios ECR estén creados:

```bash
cd IaC/terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Esto creará los siguientes repositorios ECR:
- `dev-stockwiz-api-gateway`
- `dev-stockwiz-product-service`
- `dev-stockwiz-inventory-service`

## Paso 2: Build y Push de Imágenes

### Opción 1: Usar el Makefile (Recomendado)

```bash
# Build y push en un solo comando
make docker-build-push ENV=dev TAG=latest

# O por separado
make docker-build ENV=dev
make docker-push ENV=dev TAG=latest
```

### Opción 2: Usar el Script Directamente

```bash
# Build y push de todos los servicios
./scripts/build-and-push-ecr.sh dev all

# Build y push de un servicio específico
./scripts/build-and-push-ecr.sh dev api-gateway
./scripts/build-and-push-ecr.sh dev product-service
./scripts/build-and-push-ecr.sh dev inventory-service

# El script genera automáticamente tags con timestamp y git hash
# Ejemplo de tags generados: 20251118-143025-a1b2c3d
```

### Opción 3: Manual

```bash
# 1. Login a ECR
make ecr-login ENV=dev

# 2. Obtener URLs de repositorios
cd IaC/terraform/environments/dev
terraform output ecr_repositories

# 3. Build de cada imagen
docker build -t api-gateway:latest -f app/StockWiz/api-gateway/Dockerfile app/StockWiz/api-gateway
docker build -t product-service:latest -f app/StockWiz/product-service/Dockerfile app/StockWiz/product-service
docker build -t inventory-service:latest -f app/StockWiz/inventory-service/Dockerfile app/StockWiz/inventory-service

# 4. Tag para ECR (reemplaza ACCOUNT_ID y REGION)
docker tag api-gateway:latest ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest
docker tag product-service:latest ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-product-service:latest
docker tag inventory-service:latest ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-inventory-service:latest

# 5. Push
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-product-service:latest
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-inventory-service:latest
```

## Verificar Imágenes en ECR

```bash
# Listar imágenes en un repositorio
aws ecr list-images --repository-name dev-stockwiz-api-gateway --region us-east-1

# Ver detalles de una imagen
aws ecr describe-images --repository-name dev-stockwiz-api-gateway --region us-east-1
```

## Obtener URLs de Repositorios

```bash
# Desde Terraform
cd IaC/terraform/environments/dev
terraform output ecr_repositories

# O usar el Makefile
make get-ecr-urls ENV=dev
```

## Estructura de Repositorios

Los repositorios ECR siguen esta nomenclatura:
- `${ENVIRONMENT}-stockwiz-api-gateway`
- `${ENVIRONMENT}-stockwiz-product-service`
- `${ENVIRONMENT}-stockwiz-inventory-service`

Donde `ENVIRONMENT` puede ser: `dev`, `stage`, o `prod`.

## Lifecycle Policies

Cada repositorio tiene una política de lifecycle que mantiene solo las últimas 10 imágenes. Las imágenes más antiguas se eliminan automáticamente.

## Troubleshooting

### Error: "no basic auth credentials"
```bash
# Solución: Hacer login a ECR
make ecr-login ENV=dev
```

### Error: "repository does not exist"
```bash
# Solución: Asegúrate de haber aplicado Terraform primero
cd IaC/terraform/environments/dev
terraform apply
```

### Error: "denied: Your authorization token has expired"
```bash
# Solución: Hacer login nuevamente
make ecr-login ENV=dev
```

## Integración con CI/CD

Para usar en pipelines de CI/CD, puedes usar el script directamente:

```yaml
# Ejemplo para GitHub Actions
- name: Build and Push to ECR
  run: |
    ./scripts/build-and-push.sh dev ${{ github.sha }}
```

## Próximos Pasos

Una vez que las imágenes estén en ECR, puedes:
1. Actualizar las task definitions de ECS para usar estas imágenes
2. Configurar auto-scaling basado en las imágenes
3. Implementar CI/CD para build y push automático


