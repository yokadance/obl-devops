# SonarCloud Setup - StockWiz

Guía completa para configurar SonarCloud en el proyecto StockWiz para análisis de calidad de código (Go + Python).

## 🎯 Objetivo

Implementar análisis automático de calidad de código con:
- ✅ Cobertura de tests
- ✅ Detección de bugs y vulnerabilidades
- ✅ Code smells y duplicación
- ✅ Quality Gates automáticos
- ✅ Integración con GitHub PRs

---

## 📋 Prerrequisitos

1. Cuenta en [SonarCloud](https://sonarcloud.io)
2. Repositorio en GitHub
3. Permisos de admin en el repositorio

---

## 🚀 Setup Paso a Paso

### 1. Configurar SonarCloud

#### 1.1 Crear cuenta en SonarCloud

1. Ve a [https://sonarcloud.io](https://sonarcloud.io)
2. Click en **"Log in"**
3. Selecciona **"With GitHub"**
4. Autoriza SonarCloud para acceder a tu GitHub

#### 1.2 Importar el proyecto

1. En SonarCloud dashboard, click en **"+"** → **"Analyze new project"**
2. Selecciona tu organización de GitHub
3. Busca el repositorio **"obl-devops"**
4. Click en **"Set Up"**

#### 1.3 Configurar el proyecto

1. **Choose your Analysis Method**: Selecciona **"With GitHub Actions"**
2. SonarCloud te mostrará:
   - `SONAR_TOKEN`: Token de autenticación
   - `SONAR_ORGANIZATION`: Tu organización
   - `SONAR_PROJECT_KEY`: Clave del proyecto

3. **IMPORTANTE**: Copia estos valores, los necesitarás en el siguiente paso

---

### 2. Configurar GitHub Secrets

#### 2.1 Agregar secrets al repositorio

1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. Click en **"New repository secret"**

Agrega los siguientes secrets:

| Secret Name | Valor | Descripción |
|-------------|-------|-------------|
| `SONAR_TOKEN` | (copiado de SonarCloud) | Token de autenticación |
| `SONAR_ORGANIZATION` | (copiado de SonarCloud) | Tu organización |
| `SONAR_PROJECT_KEY` | `stockwiz-devops` | Clave del proyecto |

**Ejemplo:**
```
SONAR_TOKEN: sqp_abc123def456...
SONAR_ORGANIZATION: tu-username
SONAR_PROJECT_KEY: stockwiz-devops
```

---

### 3. Configurar Quality Gates

AComo estamos usando un servicio gratuito, solo nos deja utlizar QG por defecto, si queremos agregar o cambiar los valores que trae hay que pagar.

---

### 4. Estructura del Proyecto

El análisis está configurado para los siguientes servicios:

```
app/StockWiz/
├── api-gateway/          # Go - API Gateway
│   ├── main.go
│   ├── go.mod
│   └── coverage.out      (auto-generado para tests)
│
├── inventory-service/    # Go - Inventory Service
│   ├── main.go
│   ├── go.mod
│   └── coverage.out      (auto-generado para tests)
│
└── product-service/      # Python - Product Service
    ├── main.py
    ├── requirements.txt
    └── coverage.xml       (auto-generado para pytest)
```

**⚠️ IMPORTANTE - Submódulo Git:**
- `app/StockWiz` es un submódulo git separado
- El workflow de GitHub Actions ya está configurado con `submodules: recursive` para hacer checkout automático
- Esto es necesario para que los tests y análisis funcionen correctamente en CI/CD

---

## 🧪 Configurar Tests

### Python (product-service)

#### 4.1 Crear directorio de tests

```bash
cd app/StockWiz/product-service
mkdir -p tests
```

#### 4.2 Crear archivo de configuración pytest

Crear `app/StockWiz/product-service/pytest.ini`:

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts =
    --verbose
    --cov=.
    --cov-report=xml
    --cov-report=term-missing
```

#### 4.3 Ejemplo de test

Crear `app/StockWiz/product-service/tests/test_main.py`:

```python
import pytest
from main import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200

def test_products_endpoint(client):
    """Test products list endpoint"""
    response = client.get('/products')
    assert response.status_code == 200
```

#### 4.4 Ejecutar tests localmente

```bash
cd app/StockWiz/product-service
pip install pytest pytest-cov
pytest --cov=. --cov-report=xml
```

---

### Go (api-gateway, inventory-service)

#### 4.5 Ejemplo de test Go

Crear `app/StockWiz/api-gateway/main_test.go`:

```go
package main

import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHealthEndpoint(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(healthHandler)
    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status code: got %v want %v",
            status, http.StatusOK)
    }
}
```

#### 4.6 Ejecutar tests localmente

```bash
cd app/StockWiz/api-gateway
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -html=coverage.out  # Ver reporte HTML
```

---

## 🔄 Flujo de Trabajo

### Cuando haces un commit/PR:

1. **GitHub Actions se dispara** automáticamente
2. **Ejecuta tests** de Python y Go con cobertura
3. **SonarCloud analiza** el código:
   - Bugs
   - Vulnerabilities
   - Code Smells
   - Duplicación
   - Cobertura de tests
4. **Quality Gate evalúa** si el código cumple los estándares
5. **Resultado en el PR**:
   - ✅ Quality Gate passed → Código aprobado
   - ❌ Quality Gate failed → Revisar issues

---

## 📊 Ver Resultados

### En SonarCloud Dashboard

1. Ve a [https://sonarcloud.io](https://sonarcloud.io)
2. Selecciona el proyecto **"obl-devops"**

Verás:
- **Overview**: Resumen general
- **Issues**: Bugs, Vulnerabilities, Code Smells
- **Security Hotspots**: Puntos de revisión de seguridad
- **Measures**: Métricas detalladas
- **Code**: Navegación por archivos con issues

### En GitHub PR

Cuando creas un Pull Request:

- El PR no se puede mergear si falla el Quality Gate (configurable)


## 📚 Referencias

- [SonarCloud Documentation](https://docs.sonarcloud.io/)
- [Quality Gates](https://docs.sonarcloud.io/improving/quality-gates/)
- [Python Coverage](https://docs.sonarcloud.io/enriching/test-coverage/python-test-coverage/)
- [Go Coverage](https://docs.sonarcloud.io/enriching/test-coverage/go-test-coverage/)
- [GitHub Actions Integration](https://docs.sonarcloud.io/getting-started/github/)

---
