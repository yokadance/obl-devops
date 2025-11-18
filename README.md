# StockWiz - Sistema de Gestión de Productos e Inventario

## Tabla de Contenidos
- [Introducción](#introducción)
- [Arquitectura General](#arquitectura-general)
- [Componentes de la Aplicación](#componentes-de-la-aplicación)
- [Infraestructura como Código (Terraform)](#infraestructura-como-código-terraform)
- [Flujo de Comunicación](#flujo-de-comunicación)
- [Deployment y CI/CD](#deployment-y-cicd)
- [Cómo Funciona Todo Junto](#cómo-funciona-todo-junto)
- [Comandos Útiles](#comandos-útiles)

---

## Introducción

**StockWiz** es una aplicación de gestión de productos e inventario construida con arquitectura de microservicios. El proyecto implementa las mejores prácticas de DevOps, incluyendo:

- **Microservicios**: Separación de responsabilidades en servicios independientes
- **Contenedorización**: Todo corre en contenedores Docker
- **Infraestructura como Código**: Terraform gestiona toda la infraestructura AWS
- **Alta Disponibilidad**: Despliegue en múltiples zonas de disponibilidad
- **Escalabilidad Automática**: Los servicios se escalan según la demanda

---

## Arquitectura General

### Vista de Alto Nivel

```
Internet
   │
   ▼
┌─────────────────────────────────────────────────────┐
│              Application Load Balancer              │
│         (Distribuye tráfico a los servicios)        │
└─────────────────────────────────────────────────────┘
   │
   ▼
┌─────────────────────────────────────────────────────┐
│           Amazon ECS Fargate (Contenedores)         │
│  ┌──────────────────────────────────────────────┐   │
│  │  Task (Todos los servicios en una unidad)   │   │
│  │                                              │   │
│  │  ┌──────────────┐    ┌──────────────┐      │   │
│  │  │  PostgreSQL  │◄───┤    Redis     │      │   │
│  │  │  (Database)  │    │   (Cache)    │      │   │
│  │  └──────────────┘    └──────────────┘      │   │
│  │         ▲                    ▲              │   │
│  │         │                    │              │   │
│  │  ┌──────┴────────────────────┴──────┐      │   │
│  │  │                                   │      │   │
│  │  │  ┌─────────────────────────────┐ │      │   │
│  │  │  │      API Gateway            │ │      │   │
│  │  │  │   (Frontend + Routing)      │ │      │   │
│  │  │  └─────────────────────────────┘ │      │   │
│  │  │                                   │      │   │
│  │  │  ┌─────────────────────────────┐ │      │   │
│  │  │  │    Product Service          │ │      │   │
│  │  │  │  (Gestión de productos)     │ │      │   │
│  │  │  └─────────────────────────────┘ │      │   │
│  │  │                                   │      │   │
│  │  │  ┌─────────────────────────────┐ │      │   │
│  │  │  │   Inventory Service         │ │      │   │
│  │  │  │ (Gestión de inventario)     │ │      │   │
│  │  │  └─────────────────────────────┘ │      │   │
│  │  └───────────────────────────────────┘      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### ¿Qué significa esto?

1. **Los usuarios** acceden a la aplicación a través de Internet
2. **El Load Balancer** recibe todas las peticiones y las distribuye
3. **Todos los contenedores** (PostgreSQL, Redis, API Gateway, Product Service, Inventory Service) corren juntos en la misma "Task" de ECS
4. **Los servicios se comunican** entre sí usando `localhost` porque están en la misma red interna

---

## Componentes de la Aplicación

### 1. API Gateway (Puerto 8000)

**¿Qué es?**
El API Gateway es la "puerta de entrada" de la aplicación. Es como el recepcionista de un edificio que dirige a las personas al departamento correcto.

**¿Qué hace?**
- Sirve el **frontend web** (la interfaz visual que ves en el navegador)
- Recibe todas las peticiones de los usuarios
- Redirige las peticiones a los servicios correctos:
  - `/api/products/*` → Product Service
  - `/api/inventory/*` → Inventory Service
- Implementa **caché** con Redis para respuestas más rápidas

**Tecnología:** Go (Golang)

**Archivo principal:** `app/StockWiz/api-gateway/main.go`

**Ejemplo de uso:**
```bash
# Ver la interfaz web
http://tu-alb.amazonaws.com/

# Obtener todos los productos
http://tu-alb.amazonaws.com/api/products

# Ver el inventario
http://tu-alb.amazonaws.com/api/inventory
```

---

### 2. Product Service (Puerto 8001)

**¿Qué es?**
El servicio especializado en gestionar todo lo relacionado con productos.

**¿Qué hace?**
- **Crear** nuevos productos
- **Listar** todos los productos
- **Obtener** detalles de un producto específico
- **Actualizar** información de productos
- **Eliminar** productos
- Guarda todo en **PostgreSQL**
- Usa **Redis** para cachear productos frecuentemente consultados

**Tecnología:** Python con FastAPI

**Archivo principal:** `app/StockWiz/product-service/main.py`

**Ejemplo de estructura de un producto:**
```json
{
  "id": 1,
  "name": "Laptop Dell XPS 13",
  "description": "Ultrabook potente y ligera",
  "price": 1299.99,
  "category": "Electronics"
}
```

---

### 3. Inventory Service (Puerto 8002)

**¿Qué es?**
El servicio que gestiona las existencias y ubicaciones de los productos en almacenes.

**¿Qué hace?**
- Registra **cuántas unidades** hay de cada producto
- Indica **en qué almacén** está cada producto
- Permite **actualizar cantidades** (cuando llegan o salen productos)
- Mantiene el historial de **última actualización**
- Guarda todo en **PostgreSQL**
- Usa **Redis** para caché

**Tecnología:** Go (Golang)

**Archivo principal:** `app/StockWiz/inventory-service/main.go`

**Ejemplo de estructura de inventario:**
```json
{
  "id": 1,
  "product_id": 1,
  "quantity": 50,
  "warehouse": "Warehouse A",
  "last_updated": "2025-11-18T23:02:23Z"
}
```

---

### 4. PostgreSQL (Puerto 5432)

**¿Qué es?**
La base de datos relacional donde se guarda toda la información permanente.

**¿Qué hace?**
- Almacena los **productos** (tabla `products`)
- Almacena el **inventario** (tabla `inventory`)
- Garantiza que los datos no se pierdan
- Se inicializa automáticamente con datos de ejemplo usando `init.sql`

**Tecnología:** PostgreSQL 15 Alpine (versión ligera)

**Archivo de configuración:** `app/StockWiz/postgres/Dockerfile`

**Credenciales por defecto:**
- Usuario: `admin`
- Contraseña: `admin123`
- Base de datos: `microservices_db`

**Datos iniciales:**
- 5 productos de ejemplo
- 5 registros de inventario

---

### 5. Redis (Puerto 6379)

**¿Qué es?**
Un sistema de caché en memoria que hace que la aplicación sea más rápida.

**¿Qué hace?**
- Guarda copias temporales de datos frecuentemente consultados
- Evita consultar la base de datos repetidamente
- Reduce el tiempo de respuesta de las APIs
- Los datos en caché expiran después de 5 minutos

**Ejemplo práctico:**
```
1. Usuario consulta producto ID 1
   → Se busca en PostgreSQL (lento: 50ms)
   → Se guarda en Redis

2. Otro usuario consulta producto ID 1 (dentro de 5 min)
   → Se obtiene de Redis (rápido: 1ms)

3. Después de 5 minutos
   → El caché expira
   → Siguiente consulta va a PostgreSQL nuevamente
```

**Tecnología:** Redis 7 Alpine

---

## Infraestructura como Código (Terraform)

La infraestructura AWS se define en código usando **Terraform**, organizado en módulos reutilizables.

### Estructura de Directorios

```
IaC/terraform/
├── modules/           # Módulos reutilizables
│   ├── vpc/          # Red virtual
│   ├── alb/          # Load Balancer
│   ├── ecr/          # Repositorios de imágenes
│   └── ecs/          # Orquestador de contenedores
└── environments/      # Configuraciones por entorno
    └── dev/          # Entorno de desarrollo
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
    (otros entornos)    
```

---

### Módulo VPC (Red Virtual)

**Ubicación:** `IaC/terraform/modules/vpc/`

**¿Qué es?**
Una red virtual privada en AWS donde "viven" todos los recursos.

**¿Qué crea?**
- **VPC**: La red virtual principal (CIDR: 10.0.0.0/16)
- **Subnets Públicas**: 2 subnets con acceso a Internet (para el Load Balancer)
  - Subnet 1: 10.0.1.0/24 (us-east-1a)
  - Subnet 2: 10.0.2.0/24 (us-east-1b)
- **Subnets Privadas**: 2 subnets sin acceso directo desde Internet (para los contenedores)
  - Subnet 1: 10.0.11.0/24 (us-east-1a)
  - Subnet 2: 10.0.12.0/24 (us-east-1b)
- **Internet Gateway**: Permite que las subnets públicas accedan a Internet
- **NAT Gateways**: 2 gateways (uno por zona) que permiten que los contenedores en subnets privadas accedan a Internet (para descargar imágenes, actualizar paquetes, etc.)
- **Route Tables**: Tablas de rutas que definen cómo se mueve el tráfico
- **Security Groups**: Firewalls virtuales que controlan el tráfico

**¿Por qué dos subnets de cada tipo?**
Para alta disponibilidad. Si una zona de AWS falla, la otra sigue funcionando.

**Security Groups creados:**

1. **ALB Security Group**
   - Permite tráfico HTTP (puerto 80) desde Internet
   - Permite tráfico HTTPS (puerto 443) desde Internet

2. **ECS Tasks Security Group**
   - Permite tráfico desde el ALB a los puertos de los servicios (8000, 8001, 8002)
   - Permite comunicación interna entre contenedores

---

### Módulo ALB (Application Load Balancer)

**Ubicación:** `IaC/terraform/modules/alb/`

**¿Qué es?**
Un balanceador de carga que distribuye el tráfico entre los contenedores y proporciona una única URL de acceso.

**¿Qué crea?**
- **Load Balancer**: El balanceador principal (público, accesible desde Internet)
- **Target Groups**: 3 grupos objetivo, uno para cada servicio:
  - API Gateway Target Group (puerto 8000)
  - Product Service Target Group (puerto 8001)
  - Inventory Service Target Group (puerto 8002)
- **Listener HTTP**: Escucha en el puerto 80 y redirige el tráfico
- **Listener Rules**: Reglas que determinan a qué servicio enviar cada petición:
  - `/api/products/*` → Product Service
  - `/api/inventory/*` → Inventory Service
  - Todo lo demás → API Gateway

**Health Checks:**
El ALB verifica constantemente que los servicios estén funcionando:
- Intervalo: cada 30 segundos
- Ruta: `/health` en cada servicio
- Umbral saludable: 2 chequeos exitosos consecutivos
- Umbral no saludable: 2 chequeos fallidos consecutivos

---

### Módulo ECR (Elastic Container Registry)

**Ubicación:** `IaC/terraform/modules/ecr/`

**¿Qué es?**
Un registro privado de imágenes Docker, como tu propio Docker Hub en AWS.

**¿Qué crea?**
4 repositorios de imágenes Docker:

1. **dev-stockwiz-api-gateway**
   - Guarda las imágenes del API Gateway
   - Lifecycle: mantiene últimas 10 imágenes

2. **dev-stockwiz-product-service**
   - Guarda las imágenes del Product Service
   - Lifecycle: mantiene últimas 10 imágenes

3. **dev-stockwiz-inventory-service**
   - Guarda las imágenes del Inventory Service
   - Lifecycle: mantiene últimas 10 imágenes

4. **dev-stockwiz-postgres**
   - Guarda las imágenes personalizadas de PostgreSQL (con init.sql incluido)
   - Lifecycle: mantiene últimas 5 imágenes

**Características:**
- **Versionado**: Usando tags (ej: `latest`, `v1.0.0`)

---

### Módulo ECS (Elastic Container Service)

**Ubicación:** `IaC/terraform/modules/ecs/`

**¿Qué es?**
El orquestador de contenedores que ejecuta y gestiona todos los contenedores de la aplicación.

**¿Qué crea?**

#### 1. ECS Cluster
Un cluster lógico que agrupa todas las tareas.
- Nombre: `dev-cluster`, `stage-cluster`, `prod-cluster` 
- Container Insights habilitado (métricas detalladas)

#### 2. Task Definition (Definición de Tarea)
Define cómo deben ejecutarse los contenedores. Todos los contenedores corren en una misma **Task**. Esto lo hicimos para que la comunicación entre contenedores sea correcta.

**Recursos asignados:**
- CPU: 2048 unidades (2 vCPUs)
- Memoria: 4096 MB (4 GB)

**Contenedores incluidos (en orden de inicio):**

**a) PostgreSQL**
- Puerto: 5432
- Health Check: `pg_isready -U admin -d microservices_db`
- Debe estar HEALTHY antes de iniciar los servicios

**b) Redis**
- Puerto: 6379
- Health Check: `redis-cli ping`
- Debe estar HEALTHY antes de iniciar los servicios

**c) API Gateway**
- Puerto: 8000
- Depende de: PostgreSQL y Redis (espera a que estén HEALTHY)
- Variables de entorno:
  ```
  PRODUCT_SERVICE_URL=http://localhost:8001
  INVENTORY_SERVICE_URL=http://localhost:8002
  REDIS_URL=localhost:6379
  ```

**d) Product Service**
- Puerto: 8001
- Depende de: PostgreSQL y Redis
- Variables de entorno:
  ```
  DATABASE_URL=postgresql://admin:admin123@localhost:5432/microservices_db
  REDIS_URL=redis://localhost:6379
  ```

**e) Inventory Service**
- Puerto: 8002
- Depende de: PostgreSQL y Redis
- Variables de entorno:
  ```
  DATABASE_URL=postgres://admin:admin123@localhost:5432/microservices_db?sslmode=disable
  REDIS_URL=localhost:6379
  ```

**¿Por qué localhost?**
Todos los contenedores están en la misma Task y comparten la red local, por eso pueden comunicarse usando `localhost`.

#### 3. ECS Service
Mantiene ejecutando el número deseado de tareas.
- Nombre: `dev-stockwiz`
- Desired Count: 1 tarea
- Launch Type: FARGATE (sin gestionar servidores)
- Subnets: Privadas (más seguras)
- Registro con 3 Target Groups del ALB

#### 4. Auto Scaling
Escala automáticamente según la carga:

**CPU Scaling:**
- Target: 70% de uso de CPU
- Scale Out: Cuando supera el 70%, añade más tareas
- Scale In: Cuando baja del 70%, reduce tareas
- Cooldown: 60 segundos para scale out, 300 segundos para scale in

**Memory Scaling:**
- Target: 80% de uso de memoria
- Scale Out: Cuando supera el 80%, añade más tareas
- Scale In: Cuando baja del 80%, reduce tareas
- Cooldown: 60 segundos para scale out, 300 segundos para scale in

**Límites:**
- Mínimo: 1 tarea
- Máximo: 4 tareas

#### 5. CloudWatch Log Group
Logs centralizados de todos los contenedores:
- Nombre: `/ecs/dev`
- Retención: 7 días
- Streams separados por servicio:
  - `/ecs/dev/postgres/...`
  - `/ecs/dev/redis/...`
  - `/ecs/dev/api-gateway/...`
  - `/ecs/dev/product-service/...`
  - `/ecs/dev/inventory-service/...`

---

### Terraform Backend (S3)

**¿Qué es?**
Un lugar seguro donde Terraform guarda el "estado" de la infraestructura.

**¿Por qué es importante?**
- Permite **trabajo en equipo**: varios desarrolladores pueden colaborar
- Previene **conflictos**: solo una persona puede modificar a la vez (state locking)
- **Backup automático**: historial de cambios con versionado
- **Seguridad**: encriptación de datos sensibles

**Configuración:**
```hcl
backend "s3" {
  bucket  = "stockwiz-terraform-state-493930199663"
  key     = "dev/terraform.tfstate"
  region  = "us-east-1"
  encrypt = true
}
```

**Características del bucket:**
- Versionado habilitado

---

## Flujo de Comunicación

### 1. Usuario accede a la aplicación web

```
Usuario → Internet → ALB → API Gateway (puerto 8000) → Frontend HTML/CSS/JS
```

El usuario escribe en el navegador la URL del ALB y obtiene la interfaz web.

---

### 2. Usuario consulta productos

```
Usuario → ALB → API Gateway → Product Service → PostgreSQL/Redis → Respuesta
```

Flujo detallado:

1. **Frontend hace petición:**
   ```javascript
   fetch('/api/products')
   ```

2. **ALB recibe la petición** en `/api/products`
   - Mira sus reglas de enrutamiento
   - Encuentra que `/api/products/*` debe ir al Product Service

3. **Product Service recibe la petición**

4. **Product Service consulta caché (Redis):**
   - Si hay caché: respuesta rápida (1-2ms)
   - Si no hay caché: consulta PostgreSQL (50-100ms)

5. **Respuesta viaja de vuelta:**
   ```
   PostgreSQL → Product Service → ALB → Frontend → Usuario ve los productos
   ```

---

### 3. Usuario crea un nuevo producto

```
Usuario → ALB → API Gateway → Product Service → PostgreSQL → Invalidar caché en Redis
```

Flujo detallado:

1. **Frontend envía formulario con datos del producto**

2. **ALB enruta a Product Service**

3. **Product Service valida y guarda en PostgreSQL**

4. **Se invalida el caché en Redis** para que próximas consultas vean el nuevo producto

5. **Respuesta confirma la creación**

---

### 4. Comunicación entre servicios (Service-to-Service)

Cuando un servicio necesita información de otro:

```
API Gateway → Product Service (localhost:8001) → Respuesta
API Gateway → Inventory Service (localhost:8002) → Respuesta
```

Todos los servicios usan `localhost` porque están en la misma Task de ECS.

---

## Deployment y CI/CD

### Proceso de Build y Deploy

#### 1. Build de Imágenes Docker

Cada servicio tiene su Dockerfile que define cómo construir la imagen.

**Comando de build (ejemplo para API Gateway):**
```bash
docker build --platform linux/amd64 \
  -t 493930199663.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest \
  -f app/StockWiz/api-gateway/Dockerfile \
  app/StockWiz/api-gateway
```

**Importante:** Usar `--platform linux/amd64` porque ECS Fargate requiere arquitectura AMD64.

#### 2. Push a ECR

**Login:**
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  493930199663.dkr.ecr.us-east-1.amazonaws.com
```

**Push:**
```bash
docker push 493930199663.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest
```

#### 3. Terraform Deploy

**Inicializar:**
```bash
cd IaC/terraform/environments/dev
terraform init
```

**Aplicar cambios:**
```bash
terraform apply
```

#### 4. Forzar nuevo deployment en ECS

Después de hacer push de nuevas imágenes:
```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-stockwiz \
  --force-new-deployment
```

Esto hace que ECS:
1. Descargue las nuevas imágenes de ECR
2. Inicie nuevas tareas con las nuevas imágenes
3. Verifique que estén saludables (health checks)
4. Detenga las tareas antiguas

---

## Cómo Funciona Todo Junto

### Ejemplo Completo: Usuario compra un producto

#### Paso 1: Usuario abre la aplicación

1. Usuario escribe URL en navegador
2. DNS resuelve a la IP del ALB
3. ALB recibe la petición y la envía al API Gateway
4. API Gateway responde con el HTML del frontend
5. Navegador renderiza la página

#### Paso 2: Frontend carga la lista de productos


El flujo backend:
- ALB → Product Service
- Product Service verifica Redis (caché) y si no hay caché, consulta PostgreSQL
- Guarda en Redis por X minutos/horas
- Devuelve los productos

#### Paso 3: Usuario ve stock de un producto


El flujo backend:
- ALB → Inventory Service
- Inventory Service verifica en el Redis y si no hay caché, consulta PostgreSQL
- Devuelve la información del inventario

#### Paso 4: Usuario agrega un nuevo producto


El flujo backend:
- ALB → Product Service
- Product Service valida los datos
- Inserta en PostgreSQL

---

## Comandos Útiles y algunos necesarios....

### Terraform

```bash
# Inicializar Terraform
cd IaC/terraform/environments/dev
terraform init

# Ver plan de cambios
terraform plan

# Aplicar cambios
terraform apply

# Destruir infraestructura
terraform destroy

# Ver outputs
terraform output

# Ver un output específico
terraform output alb_dns_name
```

---

### Docker

```bash
# Login a ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  493930199663.dkr.ecr.us-east-1.amazonaws.com

# Build de una imagen
docker build --platform linux/amd64 \
  -t 493930199663.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest \
  -f app/StockWiz/api-gateway/Dockerfile \
  app/StockWiz/api-gateway

# Push de imagen a ECR
docker push 493930199663.dkr.ecr.us-east-1.amazonaws.com/dev-stockwiz-api-gateway:latest

# Listar imágenes locales
docker images | grep stockwiz
```

---

### AWS CLI - ECS

```bash
# Listar clusters
aws ecs list-clusters

# Describir servicio
aws ecs describe-services --cluster dev-cluster --services dev-stockwiz

# Forzar nuevo deployment
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-stockwiz \
  --force-new-deployment

# Listar tareas
aws ecs list-tasks --cluster dev-cluster --service-name dev-stockwiz

# Escalar manualmente
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-stockwiz \
  --desired-count 2
```

---

### AWS CLI - CloudWatch Logs

```bash
# Ver logs en tiempo real
aws logs tail /ecs/dev --follow

# Ver logs de los últimos 10 minutos
aws logs tail /ecs/dev --since 10m

# Filtrar logs por servicio
aws logs tail /ecs/dev --filter-pattern "product-service"

# Buscar errores
aws logs tail /ecs/dev --filter-pattern "ERROR"
```

---

### Testing de APIs

```bash
# Listar productos
curl http://dev-alb-xxx.us-east-1.elb.amazonaws.com/api/products

# Crear producto
curl -X POST http://dev-alb-xxx.us-east-1.elb.amazonaws.com/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","description":"Test","price":99.99,"category":"Test"}'

# Obtener un producto específico
curl http://dev-alb-xxx.us-east-1.elb.amazonaws.com/api/products/1

# Listar inventario
curl http://dev-alb-xxx.us-east-1.elb.amazonaws.com/api/inventory

# Formatear respuesta con jq
curl -s http://dev-alb-xxx.us-east-1.elb.amazonaws.com/api/products | jq .
```

---

## Resumen de Arquitectura

### ¿Qué tenemos?

1. **5 Contenedores** corriendo juntos en ECS Fargate:
   - PostgreSQL (base de datos)
   - Redis (caché)
   - API Gateway (frontend + enrutamiento)
   - Product Service (gestión de productos)
   - Inventory Service (gestión de inventario)

2. **Alta Disponibilidad**:
   - Load Balancer distribuye tráfico
   - Múltiples zonas de disponibilidad
   - Auto-scaling automático

3. **Seguridad**:
   - Contenedores en subnets privadas
   - Solo el ALB es público
   - Security Groups controlando tráfico

4. **Rendimiento**:
   - Redis cachea consultas frecuentes
   - Health checks garantizan disponibilidad
   - Auto-scaling según carga

5. **Infraestructura como Código**:
   - Todo definido en Terraform
   - Versionado en Git
   - Reproducible en cualquier cuenta AWS

---

## A futuro creemos que.....

### Mejoras Sugeridas

1. **HTTPS**: Certificado SSL en el ALB con redirección HTTP → HTTPS
3. **Dominio personalizado**: Route 53 para DNS
4. **Secrets Management**: AWS Secrets Manager para credenciales
5. **Backup de base de datos**: Snapshots automáticos
6. **Monitoreo avanzado**: CloudWatch Alarms y SNS, Grafana, Victoria Metrics, Victoria Logs u otros artefactos de monitoreo.


---

## Estructura del Proyecto

```
obl-devops/
├── app/StockWiz/              # Código de la aplicación
│   ├── api-gateway/           # API Gateway (Go)
│   ├── product-service/       # Product Service (Python)
│   ├── inventory-service/     # Inventory Service (Go)
│   ├── postgres/              # PostgreSQL customizado
│   ├── init.sql               # Script de inicialización DB
│   └── docker-compose.yml     # Para desarrollo local
│
├── IaC/terraform/             # Infraestructura como Código
│   ├── modules/               # Módulos reutilizables
│   │   ├── vpc/              # Red virtual
│   │   ├── alb/              # Load Balancer
│   │   ├── ecr/              # Repositorios Docker
│   │   └── ecs/              # Orquestador de contenedores
│   └── environments/          # Configuración por ambiente
│       └── dev/              # Ambiente de desarrollo
|       └── stage/            # Ambiente de testing
|       └── prod/             # Ambiente de producción
│
└── README.md                  # Info globlal del proyecto
|
└── Makefile                  # Archivo de configuracion para lanzamiento automatizado.
|
├── scripts/                 # directorio con scripts que responden al Makefile
│   ├── build-and-push-ecr.sh # Comandos para manipulación de imagenes al registry remoto de aws
|   ├── build-and-push-ecr.sh # Comandos para manipulación de imagenes al registry remoto de aws

```

---

**Desarrollado por el equipo DevOps de StockWiz**

Para preguntas o soporte, contactar al equipo de DevOps.
