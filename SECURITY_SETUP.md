# Security Setup - Eliminación Completa de Passwords Hardcodeadas

Guía completa para configurar credenciales de forma segura. Todas las contraseñas ahora se gestionan mediante variables de entorno y secrets.

---

## Problema de Seguridad Detectado

SonarCloud detectó la contraseña `admin123` hardcodeada en múltiples archivos:
- `app/StockWiz/product-service/main.py`
- `app/StockWiz/inventory-service/main.go`
- `app/StockWiz/docker-compose.yml`
- `app/StockWiz/postgres/Dockerfile`
- `IaC/terraform/modules/ecs/main.tf`

**Solución:** Todas las contraseñas se han movido a variables de entorno.

---

## Configuración Requerida

### 1. Variables de Entorno Locales

Para desarrollo local, crea un archivo `.env` en `app/StockWiz/`:

```bash
cp app/StockWiz/.env.example app/StockWiz/.env
```

Edita `.env` y configura tu contraseña:

```bash
DB_USER=admin
DB_PASSWORD=tu_password_segura_local
DB_HOST=localhost
DB_PORT=5432
DB_NAME=microservices_db
```

**IMPORTANTE:** El archivo `.env` está en .gitignore y NUNCA debe commitearse.

### 2. Terraform Variables

Para desplegar infraestructura, debes proveer `db_password` a Terraform:

**Opción A: Variable de entorno (RECOMENDADO)**
```bash
export TF_VAR_db_password="password_segura"
cd IaC/terraform/environments/dev
terraform apply
```

**Opción B: Parámetro en línea**
```bash
terraform apply -var="db_password=password_segura"
```

**Opción C: Archivo terraform.tfvars (solo dev)**
```bash
# Copia el ejemplo
cp terraform.tfvars.example terraform.tfvars

# Edita terraform.tfvars y descomenta:
db_password = "password_segura"

# Aplica
terraform apply
```

### 3. GitHub Secrets (NO USADO actualmente)

El pipeline actual NO ejecuta terraform, solo hace build y deploy de contenedores.
Sin embargo, si en el futuro se automatiza terraform en GitHub Actions, necesitarás:

Ve a tu repositorio → **Settings** → **Secrets and variables** → **Actions**

| Secret Name | Valor | Descripción |
|-------------|-------|-------------|
| `DB_PASSWORD` | Generar con `openssl rand -base64 20` | Password de PostgreSQL |
| `DB_USER` | `admin` | Usuario de PostgreSQL |
| `DB_NAME` | `microservices_db` | Nombre de la base de datos |

---

## Cambios Realizados en el Código

### 1. Product Service (Python)

**Antes:**
```python
database_url = os.getenv("DATABASE_URL", "postgresql://admin:admin123@localhost:5432/microservices_db")
```

**Después:**
```python
db_user = os.getenv("DB_USER", "admin")
db_password = os.getenv("DB_PASSWORD", "")
db_host = os.getenv("DB_HOST", "localhost")
db_port = os.getenv("DB_PORT", "5432")
db_name = os.getenv("DB_NAME", "microservices_db")

if not db_password:
    raise ValueError("DB_PASSWORD environment variable is required")

database_url = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
```

### 2. Inventory Service (Go)

**Antes:**
```go
dbURL = "postgres://admin:admin123@localhost:5432/microservices_db?sslmode=disable"
```

**Después:**
```go
dbUser := getEnv("DB_USER", "admin")
dbPassword := os.Getenv("DB_PASSWORD")
dbHost := getEnv("DB_HOST", "localhost")
dbPort := getEnv("DB_PORT", "5432")
dbName := getEnv("DB_NAME", "microservices_db")

if dbPassword == "" {
    log.Fatal("DB_PASSWORD environment variable is required")
}

dbURL = fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
    dbUser, dbPassword, dbHost, dbPort, dbName)
```

---

### 3. Docker Compose

**Archivo:** `app/StockWiz/docker-compose.yml`

**Cambios:**
```yaml
# Antes
environment:
  POSTGRES_PASSWORD: admin123

# Después
environment:
  POSTGRES_PASSWORD: ${DB_PASSWORD}
```

Docker Compose ahora lee las variables desde el archivo `.env` automáticamente.

### 4. Postgres Dockerfile

**Archivo:** `app/StockWiz/postgres/Dockerfile`

**Cambios:**
```dockerfile
# Antes
ENV POSTGRES_PASSWORD=admin123

# Después
# POSTGRES_PASSWORD debe ser provista en runtime (no default)
```

### 5. Terraform ECS Task Definition

**Archivo:** `IaC/terraform/modules/ecs/main.tf`

**Cambios:**
```hcl
# Antes
environment = [
  {
    name  = "POSTGRES_PASSWORD"
    value = "admin123"
  }
]

# Después
environment = [
  {
    name  = "POSTGRES_PASSWORD"
    value = var.db_password  # Proviene de terraform.tfvars o TF_VAR_
  }
]
```

---

## Archivos Creados

### 1. Variables de Entorno
- `app/StockWiz/.env.example` - Template para desarrollo local
- `.gitignore` actualizado para ignorar `.env`

### 2. Terraform Variables
- `IaC/terraform/modules/ecs/variables.tf` - Variables del módulo ECS
- `IaC/terraform/environments/dev/variables.tf` - Variables del ambiente dev
- `IaC/terraform/environments/dev/terraform.tfvars.example` - Template dev
- `IaC/terraform/environments/stage/variables.tf` - Variables del ambiente stage
- `IaC/terraform/environments/stage/terraform.tfvars.example` - Template stage
- `IaC/terraform/environments/prod/variables.tf` - Variables del ambiente prod
- `IaC/terraform/environments/prod/terraform.tfvars.example` - Template prod

---

## Testing y Deployment

### Desarrollo Local

**1. Con Docker Compose:**

```bash
# Crear archivo .env
cp app/StockWiz/.env.example app/StockWiz/.env

# Editar .env con tu contraseña
# DB_PASSWORD=tu_password_local

# Levantar servicios (docker-compose lee .env automáticamente)
cd app/StockWiz
docker-compose up
```

**2. Con servicios individuales:**

```bash
# Cargar variables de entorno
export $(cat app/StockWiz/.env | xargs)

# Correr servicios
cd app/StockWiz/product-service
python main.py
```

### Deployment con Terraform

**Dev Environment:**

```bash
# Opción 1: Variable de entorno
export TF_VAR_db_password="SecureP@ssw0rd123"
cd IaC/terraform/environments/dev
terraform init
terraform apply

# Opción 2: Archivo tfvars
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars y descomentar db_password
terraform apply
```

**Otros ambientes (stage/prod):**

Mismo proceso pero en sus respectivas carpetas y con passwords diferentes.

---

## Verificación

### 1. Verificar SonarCloud

Después de hacer commit y push:

1. El pipeline ejecutará tests
2. SonarCloud escaneará el código
3. El Quality Gate debería pasar (sin issues de passwords hardcodeadas)

### 2. Verificar Servicios

```bash
# Local
curl http://localhost:8001/health
curl http://localhost:8002/health

# AWS (después de terraform apply)
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/products/health
curl http://$ALB_DNS/api/inventory/health
```

---

## Mejores Prácticas

### Seguridad

1. **Nunca** hardcodear credenciales en el código
2. **Nunca** commitear archivos `.env` o `terraform.tfvars`
3. **Generar** passwords fuertes (mínimo 16 caracteres)
4. **Rotar** passwords regularmente (cada 90 días)
5. **Usar** diferentes passwords para dev/stage/prod
6. **Considerar** AWS Secrets Manager para producción

### Generador de Password Segura

```bash
# Password alfanumérica (20 caracteres)
openssl rand -base64 20

# Password con símbolos (32 caracteres)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```

---

## Troubleshooting

### Error: "DB_PASSWORD environment variable is required"

**Causa:** La variable DB_PASSWORD no está configurada.

**Solución:**
- Local: Crea archivo `.env` con DB_PASSWORD
- Terraform: Provee `TF_VAR_db_password` o `terraform.tfvars`

### Error: SonarCloud sigue detectando passwords

**Causa:** Archivo con password hardcodeada todavía en el repositorio.

**Solución:**
```bash
# Buscar contraseñas hardcodeadas
grep -r "admin123" app/ IaC/

# Si encuentra alguna, reemplazarla con variable de entorno
```

### Error: Docker Compose no encuentra DB_PASSWORD

**Causa:** Archivo `.env` no existe o está en ubicación incorrecta.

**Solución:**
```bash
# Verificar que .env existe
ls -la app/StockWiz/.env

# Si no existe, crearlo desde el template
cp app/StockWiz/.env.example app/StockWiz/.env
```

---

## Resumen de Cambios

### Archivos Modificados
- ✅ `app/StockWiz/product-service/main.py` - Password desde env vars
- ✅ `app/StockWiz/inventory-service/main.go` - Password desde env vars
- ✅ `app/StockWiz/docker-compose.yml` - Usa ${DB_PASSWORD}
- ✅ `app/StockWiz/postgres/Dockerfile` - No default password
- ✅ `IaC/terraform/modules/ecs/main.tf` - Usa var.db_password
- ✅ `.gitignore` - Ignora .env y terraform.tfvars

### Archivos Creados
- ✅ `app/StockWiz/.env.example`
- ✅ `IaC/terraform/environments/dev/terraform.tfvars.example`
- ✅ `IaC/terraform/environments/stage/terraform.tfvars.example`
- ✅ `IaC/terraform/environments/prod/terraform.tfvars.example`
- ✅ Variables en todos los `variables.tf` (módulo y ambientes)

---
