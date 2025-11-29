# Testing Guide - StockWiz

Guía completa de testing para el proyecto StockWiz: tests unitarios, funcionales y mejores prácticas.

---

## 📋 Tabla de Contenidos

- [Quick Start](#-quick-start)
- [Filosofía de Testing](#-filosofía-de-testing)
- [Tests Unitarios](#-tests-unitarios)
- [Tests Funcionales](#-tests-funcionales)
- [Git Pre-Push Hook](#-git-pre-push-hook)
- [Escribir Buenos Tests](#-escribir-buenos-tests)
- [Coverage Goals](#-coverage-goals)
- [Troubleshooting](#-troubleshooting)

---

## 🚀 Quick Start

### TL;DR (Demasiado Largo, No Leí)

```bash
# 1. Ejecuta tests (solo requiere Docker)
./scripts/run-tests-docker.sh

# 2. Configura git hook (tests automáticos antes de push)
./scripts/setup-git-hooks.sh

# 3. Profit!
git push  # → Tests se ejecutan automáticamente
```

### Resultado Esperado

```
======================================
Ejecutando Tests con Docker
======================================

[1/3] Ejecutando Python Tests (Product Service)...
✓ Python tests pasaron (3 passed in 0.44s)

[2/3] Ejecutando Go Tests (API Gateway)...
✓ Go tests (API Gateway) pasaron

[3/3] Ejecutando Go Tests (Inventory Service)...
✓ Go tests (Inventory Service) pasaron

======================================
✅ Todos los tests pasaron
======================================
```

---

## 🎯 Filosofía de Testing

```
Test Local → Test Rápido → Test CI/CD → Deploy
```

**Regla de oro:** Nunca pushees código sin haber ejecutado tests localmente.

### Pirámide de Testing

```
         /\
        /  \  E2E Tests (Functional - Newman)
       /    \
      /------\  Integration Tests
     /        \
    /----------\ Unit Tests (Python pytest, Go test)
```

**Distribución recomendada:**
- 70% Unit Tests (base)
- 20% Integration Tests (medio)
- 10% E2E/Functional Tests (tope)

---

## 🧪 Tests Unitarios

Los tests unitarios validan funciones individuales, métodos y clases.

### Opción A: Con Docker (Recomendado)

**Ventajas:**
- ✅ No instalar nada (solo Docker Desktop)
- ✅ Ambiente consistente (misma versión de Python/Go para todos)
- ✅ Rápido setup (listo en segundos)
- ✅ Igual que CI/CD (mismo ambiente que GitHub Actions)

```bash
# Ejecutar todos los tests
./scripts/run-tests-docker.sh

# Tiempo: ~60-90 segundos
# Requisito: Solo Docker Desktop
```

**¿Cómo funciona?**
1. Crea containers temporales con imágenes oficiales
2. Monta tu código dentro del container
3. Instala dependencias
4. Ejecuta tests
5. Destruye el container

**Imágenes usadas:**
- Python: `python:3.11-slim` (~150MB)
- Go: `golang:1.21-alpine` (~350MB)

**Primera vez:** Descarga imágenes (~500MB total)
**Siguientes veces:** Usa cache, super rápido ⚡

### Opción B: Con instalación local de Python/Go

Si ya tienes Python y Go instalados:

```bash
# Python (Product Service)
cd app/StockWiz/product-service
pip install -r requirements.txt pytest pytest-cov httpx
pytest --cov=. --cov-report=term-missing

# Go (API Gateway)
cd app/StockWiz/api-gateway
go test ./... -cover

# Go (Inventory Service)
cd app/StockWiz/inventory-service
go test ./... -cover
```

### Comparación

| Aspecto | Docker | Instalación Local |
|---------|--------|-------------------|
| Setup inicial | 0 minutos | 15-30 minutos |
| Dependencias | Automáticas | Manuales |
| Consistencia | ✅ 100% | ⚠️ Varía por sistema |
| Limpieza | ✅ Isolado | ❌ Modifica sistema |
| Tiempo tests | ~60-90s | ~30-60s |

---

## 🌐 Tests Funcionales

Los tests funcionales validan endpoints API completos mediante Postman/Newman.

### Colección de Tests

La colección incluye:

**1. Health Checks**
- API Gateway Health
- Product Service Health
- Inventory Service Health

**2. Product Service Tests**
- Get All Products
- Create Product
- Get Product by ID

**3. Inventory Service Tests**
- Get Inventory
- Update Inventory

**4. Integration Tests**
- Full Flow (validación end-to-end)

### Ejecutar Tests Funcionales

**Prerequisitos:**
```bash
# Instalar Newman (solo primera vez)
npm install -g newman newman-reporter-htmlextra
```

**Contra ambiente local:**
```bash
# 1. Asegúrate de que los servicios estén corriendo
docker-compose up -d

# 2. Ejecutar tests
newman run tests/postman/StockWiz-API-Tests.postman_collection.json \
  -e tests/postman/dev.postman_environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-report.html
```

**Contra ambiente AWS (Dev):**
```bash
# 1. Obtener el DNS del ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names dev-stockwiz-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "Testing against: http://$ALB_DNS"

# 2. Actualizar environment file
sed "s|http://localhost:8080|http://$ALB_DNS|g" \
  tests/postman/dev.postman_environment.json > temp.json

# 3. Ejecutar tests
newman run tests/postman/StockWiz-API-Tests.postman_collection.json \
  -e temp.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman-report.html

# 4. Abrir reporte
open newman-report.html  # macOS
```

### Output Esperado

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

### Agregar Nuevos Tests

**En Postman Desktop:**
1. Importar la colección: `tests/postman/StockWiz-API-Tests.postman_collection.json`
2. Agregar un nuevo request a la carpeta correspondiente
3. Agregar tests en la pestaña "Tests":

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

4. Exporta la colección y reemplaza el archivo JSON

---

## 🪝 Git Pre-Push Hook

El git hook ejecuta tests automáticamente antes de cada push.

### Instalación

```bash
# Ejecutar una sola vez
./scripts/setup-git-hooks.sh
```

### ¿Qué hace?

Antes de cada `git push`:
1. ✅ Ejecuta tests usando **Docker** (no requiere Python/Go instalado)
2. ✅ Ejecuta tests de Python con `python:3.11-slim`
3. ✅ Ejecuta tests de Go con `golang:1.21-alpine`
4. ❌ **Bloquea el push** si algún test falla

**Requisito único:** Docker Desktop instalado y corriendo

### Saltar el hook (emergencias)

```bash
# NO recomendado, solo en emergencias
git push --no-verify
```

### Ejecutar manualmente

```bash
# Ejecutar los mismos tests que el hook sin hacer push
./scripts/run-tests-docker.sh
```

---

## 📝 Escribir Buenos Tests

### Python (pytest)

**✅ GOOD: Test específico, claro, independiente**
```python
def test_create_product_returns_201():
    """Test que crear producto retorna status 201"""
    response = client.post('/products', json={
        'name': 'Test Product',
        'price': 99.99
    })

    assert response.status_code == 201
    assert response.json()['name'] == 'Test Product'
```

**❌ BAD: Test ambiguo, múltiples asserts no relacionados**
```python
def test_product():
    response = client.get('/products')
    assert response.status_code == 200
    assert len(response.json()) > 0
    response2 = client.post('/products', json={})
    assert response2.status_code == 400
```

### Go (testing)

**✅ GOOD: Table-driven test**
```go
func TestCalculatePrice(t *testing.T) {
    tests := []struct {
        name     string
        quantity int
        price    float64
        want     float64
    }{
        {"single item", 1, 10.0, 10.0},
        {"multiple items", 5, 10.0, 50.0},
        {"zero quantity", 0, 10.0, 0.0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := calculatePrice(tt.quantity, tt.price)
            if got != tt.want {
                t.Errorf("got %v, want %v", got, tt.want)
            }
        })
    }
}
```

**❌ BAD: Un solo caso, no descriptivo**
```go
func TestPrice(t *testing.T) {
    result := calculatePrice(5, 10.0)
    if result != 50.0 {
        t.Fail()
    }
}
```

### Mejores Prácticas

**DO:**
- ✅ Un test por funcionalidad
- ✅ Nombres descriptivos (`test_create_product_returns_201`)
- ✅ Arrange-Act-Assert pattern
- ✅ Tests independientes (no dependen de orden)
- ✅ Mock de dependencias externas
- ✅ Verificar casos edge (valores null, vacíos, negativos)

**DON'T:**
- ❌ Tests sin asserts
- ❌ Tests que dependen del orden
- ❌ Tests con sleeps/waits arbitrarios
- ❌ Tests que modifican estado global sin restaurar
- ❌ Llamadas reales a APIs externas
- ❌ Tests que prueban múltiples cosas no relacionadas

---

## 🎯 Coverage Goals

### Mínimos Requeridos

| Tipo de Código | Coverage Mínimo | Ideal |
|----------------|-----------------|-------|
| Business Logic | 90% | 95%+ |
| Controllers/Handlers | 80% | 90% |
| Utils/Helpers | 85% | 95% |
| Config/Setup | 50% | 70% |

### Verificar Coverage

**Python:**
```bash
cd app/StockWiz/product-service
pytest --cov=. --cov-report=html
open htmlcov/index.html
```

**Go:**
```bash
cd app/StockWiz/api-gateway
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Interpretar Coverage

```
============================= coverage =============================
Name                 Stmts   Miss  Cover   Missing
----------------------------------------------------
main.py                134     91    32%   39-57, 63-64, 69...
tests/test_main.py      19      2    89%   24-25
----------------------------------------------------
TOTAL                  153     93    39%
```

**Qué significa:**
- ✅ **3 passed** - Todos los tests pasan
- 📊 **39% coverage** - Solo 39% del código está testeado (mejorable)
- ⚡ **0.44s** - Tests super rápidos
- 🎯 **Missing** - Líneas específicas sin cobertura

---

## 🔄 Workflow Recomendado

### Nivel 1: Durante Desarrollo (Loop rápido)

```bash
# Mientras escribes código, ejecuta tests continuamente
cd app/StockWiz/product-service

# Python: watch mode
pytest-watch  # o manualmente: pytest

# Go: watch mode
cd ../api-gateway
# Instalar: go install github.com/cespare/reflex@latest
reflex -r '\.go$' -- go test ./...
```

**Frecuencia:** Cada 1-5 minutos mientras desarrollas

### Nivel 2: Antes de Commit (Validación local)

```bash
# Ejecutar TODOS los tests con un solo comando
./scripts/run-tests-docker.sh

# Tiempo: ~60-90 segundos
# Requisito: Solo Docker Desktop
```

**Frecuencia:** Antes de cada commit

### Nivel 3: Antes de Push (Validación completa)

```bash
# Opción A: Setup git hook automático (recomendado)
./scripts/setup-git-hooks.sh

# Ahora cada push ejecutará tests automáticamente
git push  # → Tests se ejecutan antes del push

# Opción B: Manual
./scripts/run-tests-docker.sh
git push
```

**Frecuencia:** Antes de cada push

### Nivel 4: CI/CD Pipeline (Validación final)

Automático en GitHub Actions cuando:
- Haces push a dev/develop
- Creas/actualizas un PR

**Tests ejecutados:**
1. Unit tests (Python + Go)
2. SonarCloud quality gate
3. Docker builds
4. Deploy a ECS (solo push a dev)
5. Functional tests (Newman)

**Tiempo total:** 18-28 minutos

---

## ⚡ Performance de Tests

### Tiempos Objetivo

| Tipo | Tiempo Ideal | Máximo Aceptable |
|------|--------------|------------------|
| Unit test individual | < 10ms | 100ms |
| Suite de unit tests | < 1s | 5s |
| Integration test | < 100ms | 1s |
| Functional test | < 500ms | 3s |

### Optimizar Tests Lentos

**✅ GOOD: Mock de dependencias externas**
```python
@patch('requests.get')
def test_fetch_data(mock_get):
    mock_get.return_value = Mock(status_code=200)
    result = fetch_data()
    assert result is not None
```

**❌ BAD: Llamadas reales a APIs**
```python
def test_fetch_data():
    result = requests.get('https://external-api.com/data')
    assert result.status_code == 200
```

---

## 🔍 Troubleshooting

### Error: "Docker no está disponible"

**Solución:**
1. Instala Docker Desktop: https://www.docker.com/products/docker-desktop
2. Inicia Docker Desktop
3. Espera a que diga "Docker is running"
4. Vuelve a intentar

### Error: "Permission denied"

**Solución:**
```bash
chmod +x scripts/run-tests-docker.sh
chmod +x scripts/setup-git-hooks.sh
```

### Tests tardan mucho la primera vez

**Es normal!**
- Primera vez: ~2-3 minutos (descarga imágenes)
- Siguientes veces: ~60-90 segundos (usa cache)

### "WARNING: Running pip as root"

**Puedes ignorarlo**
- Es solo un warning, no un error
- Estamos en un container temporal, no importa

### Tests pasan local, fallan en CI

**Causas comunes:**

1. **Variables de entorno diferentes**
   ```bash
   # Verifica que .env.test esté en .gitignore
   # Usa valores por defecto en tests
   ```

2. **Dependencias de versión**
   ```bash
   # Pin exacto de versiones
   pip freeze > requirements.txt
   ```

3. **Estado compartido entre tests**
   ```bash
   # Ejecutar tests en orden aleatorio
   pytest --random-order
   ```

4. **Timing issues**
   ```bash
   # No usar sleeps, usar polling
   # Aumentar timeouts para CI
   ```

### Error: "newman: command not found"

```bash
npm install -g newman newman-reporter-htmlextra
```

### Error: "ECONNREFUSED"

**Causa**: Servicios no están corriendo

**Solución:**
```bash
# Verificar que los servicios estén up
docker-compose ps
```

### Error: "Timeout of 2000ms exceeded"

**Causa**: Servicio lento o no responde

**Solución**: Aumentar timeout en la colección:
```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
}, 5000); // 5 segundos
```

---

## ✅ Checklist Diario

Antes de terminar tu día de trabajo:

- [ ] Todos los tests unitarios pasan localmente
- [ ] Coverage ≥ 80% en código nuevo
- [ ] No hay warnings de linter
- [ ] Tests funcionales pasan (si tienes servicios corriendo)
- [ ] Commits tienen mensajes descriptivos
- [ ] Push a remote backup

---

## 📚 Recursos

### Herramientas

- **pytest**: https://docs.pytest.org/
- **pytest-cov**: https://pytest-cov.readthedocs.io/
- **Go testing**: https://golang.org/pkg/testing/
- **Newman**: https://learning.postman.com/docs/running-collections/using-newman-cli/

### Guías

- [Testing Python Applications](https://realpython.com/pytest-python-testing/)
- [Table Driven Tests in Go](https://dave.cheney.net/2019/05/07/prefer-table-driven-tests)
- [Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)

---

## 🔗 Documentación Relacionada

- [README.md](README.md) - Introducción y arquitectura general
- [DEPLOYMENT.md](DEPLOYMENT.md) - Guía de deployment
- [PIPELINE.md](PIPELINE.md) - CI/CD pipeline
- [MONITORING.md](MONITORING.md) - Monitoreo y alertas

---
