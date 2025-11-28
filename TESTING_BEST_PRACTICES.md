# Testing Best Practices - StockWiz

Guía de mejores prácticas para testing en el proyecto StockWiz.

---

## 🎯 Filosofía de Testing

```
Test Local → Test Rápido → Test CI/CD → Deploy
```

**Regla de oro:** Nunca pushees código sin haber ejecutado tests localmente.

---

## 📊 Pirámide de Testing

```
         /\
        /  \  E2E Tests (Functional - Newman)
       /    \
      /------\  Integration Tests
     /        \
    /----------\ Unit Tests (Python pytest, Go test)
```

### 1. Unit Tests (Base - 70%)
- **Qué:** Funciones individuales, métodos, clases
- **Cuándo:** Siempre, antes de cada commit
- **Dónde:** Local
- **Tiempo:** Segundos

### 2. Integration Tests (Medio - 20%)
- **Qué:** Interacción entre componentes (DB, Redis, servicios)
- **Cuándo:** Antes de push
- **Dónde:** Local + CI/CD
- **Tiempo:** 1-3 minutos

### 3. E2E/Functional Tests (Tope - 10%)
- **Qué:** Flujos completos de usuario via API
- **Cuándo:** Antes de merge a dev/staging
- **Dónde:** Local (opcional) + CI/CD (obligatorio)
- **Tiempo:** 2-5 minutos

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

---

### Nivel 2: Antes de Commit (Validación local)

```bash
# 1. Ejecutar TODOS los tests unitarios
cd app/StockWiz/product-service
pytest --cov=. --cov-report=term-missing

cd ../api-gateway
go test ./... -cover

cd ../inventory-service
go test ./... -cover

# 2. Verificar coverage mínimo
# Python: >= 80%
# Go: >= 60%
```

**Frecuencia:** Antes de cada commit

**Tiempo total:** 30-60 segundos

---

### Nivel 3: Antes de Push (Validación completa)

```bash
# Opción A: Setup git hook automático (recomendado)
./scripts/setup-git-hooks.sh

# Ahora cada push ejecutará tests automáticamente
git push  # → Tests se ejecutan antes del push

# Opción B: Manual
# 1. Tests unitarios (ya los hiciste en nivel 2)

# 2. Tests funcionales locales (si tienes servicios corriendo)
./scripts/run-functional-tests.sh local

# 3. Si todo pasa → Push
git push origin feature/mi-feature
```

**Frecuencia:** Antes de cada push

**Tiempo total:** 1-3 minutos

---

### Nivel 4: CI/CD Pipeline (Validación final)

```bash
# Automático - no requiere acción manual
# Se ejecuta en GitHub Actions cuando:
# - Haces push a dev/develop
# - Creas/actualizas un PR

# Tests ejecutados:
# 1. Unit tests (Python + Go)
# 2. SonarCloud quality gate
# 3. Docker builds
# 4. Deploy a ECS (solo push a dev)
# 5. Functional tests (Newman)
```

**Frecuencia:** Cada push/PR

**Tiempo total:** 18-28 minutos

---

## 🛠️ Setup: Git Pre-Push Hook

### Instalación

```bash
# Ejecutar una sola vez
./scripts/setup-git-hooks.sh
```

### Qué hace

Antes de cada `git push`:
1. ✅ Ejecuta tests de Python
2. ✅ Ejecuta tests de Go (api-gateway)
3. ✅ Ejecuta tests de Go (inventory-service)
4. ❌ **Bloquea el push** si algún test falla

### Saltar el hook (emergencias)

```bash
# NO recomendado, solo en emergencias
git push --no-verify
```

---

## 📝 Escribir Buenos Tests

### Python (pytest)

```python
# ✅ GOOD: Test específico, claro, independiente
def test_create_product_returns_201():
    """Test que crear producto retorna status 201"""
    response = client.post('/products', json={
        'name': 'Test Product',
        'price': 99.99
    })

    assert response.status_code == 201
    assert response.json()['name'] == 'Test Product'

# ❌ BAD: Test ambiguo, múltiples asserts no relacionados
def test_product():
    response = client.get('/products')
    assert response.status_code == 200
    assert len(response.json()) > 0
    response2 = client.post('/products', json={})
    assert response2.status_code == 400
```

### Go (testing)

```go
// ✅ GOOD: Table-driven test
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

// ❌ BAD: Un solo caso, no descriptivo
func TestPrice(t *testing.T) {
    result := calculatePrice(5, 10.0)
    if result != 50.0 {
        t.Fail()
    }
}
```

---

## 🎯 Coverage Goals

### Mínimos requeridos

| Tipo de Código | Coverage Mínimo | Ideal |
|----------------|-----------------|-------|
| Business Logic | 90% | 95%+ |
| Controllers/Handlers | 80% | 90% |
| Utils/Helpers | 85% | 95% |
| Config/Setup | 50% | 70% |

### Verificar coverage

```bash
# Python
pytest --cov=. --cov-report=html
open htmlcov/index.html

# Go
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

---

## ⚡ Performance de Tests

### Tiempos objetivo

| Tipo | Tiempo Ideal | Máximo Aceptable |
|------|--------------|------------------|
| Unit test individual | < 10ms | 100ms |
| Suite de unit tests | < 1s | 5s |
| Integration test | < 100ms | 1s |
| Functional test | < 500ms | 3s |

### Optimizar tests lentos

```python
# ✅ GOOD: Mock de dependencias externas
@patch('requests.get')
def test_fetch_data(mock_get):
    mock_get.return_value = Mock(status_code=200)
    result = fetch_data()
    assert result is not None

# ❌ BAD: Llamadas reales a APIs
def test_fetch_data():
    result = requests.get('https://external-api.com/data')
    assert result.status_code == 200
```

---

## 🚨 Anti-Patterns a Evitar

### 1. ❌ Tests que dependen del orden

```python
# MAL - test2 depende de test1
def test_create_user():
    global user_id
    user_id = create_user('john')

def test_delete_user():
    delete_user(user_id)  # Falla si test_create_user no corrió
```

**Solución:** Usar fixtures/setup independientes

### 2. ❌ Tests sin asserts

```python
# MAL - no verifica nada
def test_process_data():
    process_data(input_data)
    # No assert! Test siempre pasa
```

**Solución:** Siempre verificar el resultado esperado

### 3. ❌ Tests con sleeps/waits arbitrarios

```python
# MAL - timing frágil
def test_async_operation():
    start_operation()
    time.sleep(2)  # Asume que termina en 2s
    assert operation_complete()
```

**Solución:** Usar polling con timeout o mocks

### 4. ❌ Tests que modifican estado global

```python
# MAL - modifica configuración global
def test_with_debug_mode():
    os.environ['DEBUG'] = 'true'
    run_test()
    # No restaura el valor original
```

**Solución:** Usar fixtures que restauren estado

---

## 📊 Monitoring de Calidad

### SonarCloud Quality Gate

Criterios que DEBE cumplir tu código:

- ✅ Coverage ≥ 80%
- ✅ 0 bugs de severidad alta
- ✅ 0 vulnerabilidades
- ✅ Duplicación ≤ 3%
- ✅ Code smells ≤ 0.8% (rating A)

### Ver en SonarCloud

```bash
# Dashboard del proyecto
https://sonarcloud.io/project/overview?id=stockwiz-devops

# Después de cada push, revisa:
# - New Code coverage
# - Issues introducidos
# - Security hotspots
```

---

## 🔍 Debugging Tests Fallidos

### Tests fallan localmente

```bash
# 1. Ejecutar test específico con verbose
pytest tests/test_main.py::test_create_product -v

# 2. Ver output completo
pytest -v -s  # -s muestra prints

# 3. Debugger
pytest --pdb  # Entra a debugger en fallo
```

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

---

## 🎓 Test-Driven Development (TDD)

### Flujo Red-Green-Refactor

```bash
# 1. RED - Escribir test que falla
def test_calculate_discount():
    assert calculate_discount(100, 0.1) == 90

# 2. GREEN - Implementar código mínimo que pase
def calculate_discount(price, discount):
    return price * (1 - discount)

# 3. REFACTOR - Mejorar sin romper tests
def calculate_discount(price: float, discount: float) -> float:
    """Calculate price after discount."""
    if not 0 <= discount <= 1:
        raise ValueError("Discount must be between 0 and 1")
    return price * (1 - discount)
```

**Beneficios:**
- ✅ Mejor diseño de código
- ✅ Tests como documentación
- ✅ Mayor confianza en refactoring
- ✅ Menos bugs en producción

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

## ✅ Checklist Diario

Antes de terminar tu día de trabajo:

- [ ] Todos los tests unitarios pasan localmente
- [ ] Coverage ≥ 80% en código nuevo
- [ ] No hay warnings de linter
- [ ] Tests funcionales pasan (si tienes servicios corriendo)
- [ ] Commits tienen mensajes descriptivos
- [ ] Push a remote backup

---
