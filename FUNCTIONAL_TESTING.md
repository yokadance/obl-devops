# Testing Funcional con Postman/Newman

Guía completa para ejecutar y mantener tests funcionales de endpoints en StockWiz.

---

## 🎯 Objetivo

Validar automáticamente que todos los endpoints de la API funcionan correctamente después de cada deployment mediante:
- ✅ Tests de health checks
- ✅ Tests de endpoints CRUD
- ✅ Tests de integración entre servicios
- ✅ Validación de tiempos de respuesta
- ✅ Validación de estructura de datos

---

## 📁 Estructura de Archivos

```
tests/postman/
├── StockWiz-API-Tests.postman_collection.json    # Colección de tests
└── dev.postman_environment.json                   # Variables de entorno
```

---

## 🧪 Colección de Tests

La colección incluye las siguientes categorías de tests:

### 1. Health Checks
- **API Gateway Health**: Valida que el gateway esté respondiendo
- **Product Service Health**: Valida que el servicio de productos esté saludable
- **Inventory Service Health**: Valida que el servicio de inventario esté saludable

### 2. Product Service Tests
- **Get All Products**: Lista todos los productos
- **Create Product**: Crea un producto de prueba
- **Get Product by ID**: Obtiene un producto específico

### 3. Inventory Service Tests
- **Get Inventory**: Lista el inventario completo
- **Update Inventory**: Actualiza cantidades de inventario

### 4. Integration Tests
- **Full Flow**: Valida que toda la cadena de servicios funcione correctamente

---

## 🚀 Ejecución Local

### Prerrequisitos

1. **Instalar Node.js** (v14+)
2. **Instalar Newman/Postman**:
   ```bash
   npm install -g newman newman-reporter-htmlextra
   ```

### Ejecutar tests contra ambiente local

```bash
# 1. los servicios estén corriendo?
docker-compose up -d  

# 2. Ejecutar la colección pal testing
newman run tests/postman/StockWiz-API-Tests.postman_collection.json \
  -e tests/postman/dev.postman_environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-report.html
```

### Ejecutar tests contra ambiente AWS (Dev)

```bash
# 1. Obtener el DNS del ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names dev-stockwiz-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "Testing against: http://$ALB_DNS"

# 2. Actualizar el environment file
sed "s|http://localhost:8080|http://$ALB_DNS|g" \
  tests/postman/dev.postman_environment.json > temp.json

# 3. Ejecutar tests
newman run tests/postman/StockWiz-API-Tests.postman_collection.json \
  -e temp.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-report.html

# 4. Abrir reporte
open newman-report.html  # macOS
# xdg-open newman-report.html  # Linux
```

---

## 🔄 Integración con CI/CD

Los tests funcionales se ejecutan **automáticamente** en el pipeline después del deployment a ECS.

### Flujo en GitHub Actions

```
1. Deploy to ECS (Job 3)
   ↓
2. Wait for services to stabilize
   ↓
3. Run Functional Tests (Job 4)
   ↓
4. Generate Newman HTML Report
   ↓
5. Upload report as artifact
   ↓
6. Notification (Job 5)
```

### Cuándo se ejecutan

- ✅ **Push a `dev`**: Ejecuta tests completos
- ✅ **Push a `develop`**: Ejecuta tests completos
- ❌ **Pull Requests**: NO ejecuta (solo tests unitarios)

### Ver resultados en GitHub

1. Ve a: `Actions` → Workflow run
2. Scroll hasta **"🧪 Functional API Tests"**
3. Descarga el artifact **"newman-test-report"**
4. Abre el archivo HTML en tu navegador

---

## 📝 Escribir Nuevos Tests

### Agregar un nuevo endpoint test

1. **Abrir Postman Desktop**
2. **Importar la colección**: `tests/postman/StockWiz-API-Tests.postman_collection.json`
3. **Agregar un nuevo request** a la carpeta correspondiente
4. **Agregar tests en la pestaña "Tests"**:

```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has expected fields", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('id');
    pm.expect(jsonData).to.have.property('name');
});

pm.test("Response time is acceptable", function () {
    pm.expect(pm.response.responseTime).to.be.below(2000);
});
```

5. **Exporta la colección** y reemplaza el archivo JSON 

### Ejemplo: Test de DELETE endpoint

```javascript
// Request: DELETE {{base_url}}/products/{{product_id}}

// Tests tab:
pm.test("Delete successful", function () {
    pm.response.to.have.status(204);
});

pm.test("Verify product deleted", function () {
    // Podría seguir con un GET para verificar
});
```

---


### Tests fallando en CI/CD

1. **Revisar logs del workflow**:
   - GitHub → Actions → Workflow run
   - Click en "🧪 Functional API Tests"
   - Revisa cada step

2. **Descargar el Newman report**:
   - Scroll hasta "Artifacts"
   - Download "newman-test-report"
   - Abre el HTML para ver detalles

3. **Problemas comunes**:
   - Services no están ready → Aumentar wait time
   - ALB DNS incorrecto → Verificar AWS credentials
   - Timeout → Aumentar timeout en collection

---

## 📊 Reportes

### CLI Output

Cuando ejecutas Newman/Postman, se genera:
```
┌─────────────────────────┬────────────┬────────────┐
│                         │   executed │     failed │
├─────────────────────────┼────────────┼────────────┤
│              iterations │          1 │          0 │
├─────────────────────────┼────────────┼────────────┤
│                requests │         10 │          0 │
├─────────────────────────┼────────────┼────────────┤
│            test-scripts │         10 │          0 │
├─────────────────────────┼────────────┼────────────┤
│      prerequest-scripts │         10 │          0 │
├─────────────────────────┼────────────┼────────────┤
│              assertions │         30 │          0 │
└─────────────────────────┴────────────┴────────────┘
```

### HTML Report (htmlextra)

El reporte HTML incluye:
- Summary dashboard con métricas
- Request/response details
- Test results por request
- Response times
- Failed test details con stack traces
- Environment variables usadas

---

## 🛠️ Variables de Entorno

### Variables disponibles

En `dev.postman_environment.json`:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `base_url` | URL base de la API | `http://dev-alb.us-east-1.elb.amazonaws.com` |
| `product_id` | ID de producto para tests | `1` (se actualiza dinámicamente) |
| `api_version` | Versión de la API | `v1` |

### Usar variables en requests

En Postman:
```
GET {{base_url}}/products/{{product_id}}
```

### Actualizar variables dinámicamente

En el tab "Tests" de un request:
```javascript
// Guardar ID del producto creado
var jsonData = pm.response.json();
pm.environment.set("product_id", jsonData.id);
```


---

## 🔗 Referencias

- [Newman Documentation](https://learning.postman.com/docs/running-collections/using-newman-cli/command-line-integration-with-newman/)
- [Postman Test Scripts](https://learning.postman.com/docs/writing-scripts/test-scripts/)
- [Newman HTML Extra Reporter](https://www.npmjs.com/package/newman-reporter-htmlextra)
- [Pipeline Dev Documentation](PIPELINE_DEV.md)

---

## 🚨 Troubleshooting

### Error: "newman: command not found"

```bash
npm install -g newman
```

### Error: "ECONNREFUSED"

**Causa**: Servicios no están corriendo

**Solución**:
```bash
# Verificar que los servicios estén up
docker-compose ps
# o
kubectl get pods
```

### Error: "Timeout of 2000ms exceeded"

**Causa**: Servicio lento o no responde

**Solución**: Aumentar timeout en la colección:
```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
}, 5000); // 5 segundos
```
