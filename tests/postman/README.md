# Postman/Newman Tests - StockWiz

Colección de tests funcionales para validar endpoints de la API StockWiz.

---

## 📁 Archivos

- **StockWiz-API-Tests.postman_collection.json**: Colección de tests
- **dev.postman_environment.json**: Variables de entorno para dev

---

## 🚀 Quick Start

### Ejecutar tests localmente

```bash
# Instalar Newman
npm install -g newman newman-reporter-htmlextra

# Ejecutar tests
newman run StockWiz-API-Tests.postman_collection.json \
  -e dev.postman_environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export report.html

# Abrir reporte
open report.html
```

### Ejecutar tests contra AWS Dev

```bash
# Obtener ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names dev-stockwiz-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Actualizar environment
sed "s|http://localhost:8080|http://$ALB_DNS|g" \
  dev.postman_environment.json > temp-env.json

# Ejecutar tests
newman run StockWiz-API-Tests.postman_collection.json \
  -e temp-env.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export report.html
```

---

## 📝 Tests Incluidos

### Health Checks
- API Gateway Health
- Product Service Health
- Inventory Service Health

### Product Service
- Get All Products
- Create Product
- Get Product by ID

### Inventory Service
- Get Inventory
- Update Inventory

### Integration Tests
- Full service chain validation

---

## 🔧 Modificar Tests

### Usando Postman Desktop

1. Importa la colección en Postman
2. Modifica/agrega requests y tests
3. Exporta la colección (Collection → Export → v2.1)
4. Reemplaza el archivo JSON

### Usando el Editor

```json
{
  "name": "Nuevo Test",
  "event": [{
    "listen": "test",
    "script": {
      "exec": [
        "pm.test('Status code is 200', function () {",
        "    pm.response.to.have.status(200);",
        "});"
      ]
    }
  }],
  "request": {
    "method": "GET",
    "url": "{{base_url}}/endpoint"
  }
}
```

---

## 📊 Ver Reportes en CI/CD

1. Ve a GitHub Actions → Workflow run
2. Scroll a "🧪 Functional API Tests"
3. Descarga artifact "newman-test-report"
4. Abre el HTML en tu navegador

---

## 📚 Documentación

Ver [FUNCTIONAL_TESTING.md](../../FUNCTIONAL_TESTING.md) para guía completa.

---
