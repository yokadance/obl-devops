# Quick Start - Testing con Docker

Guía rápida para ejecutar tests **sin instalar Python o Go** localmente.

---

## 🎯 TL;DR (Demasiado Largo, No Leí)

```bash
# 1. Ejecuta tests (solo requiere Docker)
./scripts/run-tests-docker.sh

# 2. Configura git hook (tests automáticos antes de push)
./scripts/setup-git-hooks.sh

# 3. Profit! 🎉
git push  # → Tests se ejecutan automáticamente
```

---

## ✅ Resultado del Test de Hoy

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

**Coverage Python:** 39% (necesita más tests, pero los existentes pasan ✅)

---

## 🐳 Por qué Docker?

### Ventajas

✅ **No instalar nada** - Solo Docker Desktop
✅ **Ambiente consistente** - Misma versión de Python/Go para todos
✅ **Rápido setup** - Listo en segundos
✅ **Igual que CI/CD** - Mismo ambiente que GitHub Actions
✅ **Limpio** - No contamina tu sistema local

### Comparación

| Aspecto | Docker | Instalación Local |
|---------|--------|-------------------|
| Setup inicial | 0 minutos | 15-30 minutos |
| Dependencias | Automáticas | Manuales |
| Consistencia | ✅ 100% | ⚠️ Varía por sistema |
| Limpieza | ✅ Isolado | ❌ Modifica sistema |
| Tiempo tests | ~60-90s | ~30-60s |

---

## 🚀 Cómo Funciona

### Script: `run-tests-docker.sh`

```bash
#!/bin/bash
# Para cada servicio:
# 1. Crea un container temporal con la imagen oficial
# 2. Monta tu código dentro del container
# 3. Instala dependencias
# 4. Ejecuta tests
# 5. Destruye el container
```

### Imágenes usadas

- **Python:** `python:3.11-slim` (oficial, ~150MB)
- **Go:** `golang:1.21-alpine` (oficial, ~350MB)

**Primera vez:** Descarga imágenes (~500MB total)
**Siguientes veces:** Usa cache, super rápido ⚡

---

## 🎓 Workflow Diario Recomendado

### Durante desarrollo

```bash
# Mientras escribes código, NO ejecutes tests constantemente
# Espera a tener un cambio significativo
```

### Antes de commit

```bash
# Ejecutar tests con Docker
./scripts/run-tests-docker.sh

# Si pasan → Commit
git add .
git commit -m "feat: nueva funcionalidad"
```

### Antes de push

```bash
# Opción A: Hook automático (recomendado)
git push  # → Tests se ejecutan automáticamente

# Opción B: Manual
./scripts/run-tests-docker.sh
git push
```

---

## 📊 Output Detallado

### Python Tests

```
============================= test session starts ==============================
platform linux -- Python 3.11.14, pytest-9.0.1, pluggy-1.6.0
collected 3 items

tests/test_main.py::test_environment_variables PASSED                    [ 33%]
tests/test_main.py::test_import_main PASSED                              [ 66%]
tests/test_main.py::test_app_routes PASSED                               [100%]

================================ tests coverage ================================
Name                 Stmts   Miss  Cover   Missing
--------------------------------------------------
main.py                134     91    32%   39-57, 63-64, 69...
tests/test_main.py      19      2    89%   24-25
--------------------------------------------------
TOTAL                  153     93    39%

============================== 3 passed in 0.44s ===============================
```

**Qué significa:**
- ✅ **3 passed** - Todos los tests pasan
- 📊 **39% coverage** - Solo 39% del código está testeado (mejorable)
- ⚡ **0.44s** - Tests super rápidos

### Go Tests

```
?       github.com/yourusername/api-gateway     [no test files]
```

**Qué significa:**
- ℹ️ **no test files** - No hay tests de Go aún (normal en etapa inicial)
- ✅ No falla - Ausencia de tests no es error

---

## 🛠️ Troubleshooting

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

---

## 🎯 Próximos Pasos

### 1. Mejorar Coverage

```bash
# Objetivo: Subir de 39% a 80%+
cd app/StockWiz/product-service

# Agregar más tests en tests/test_main.py
# Ver qué falta testear:
pytest --cov=. --cov-report=html
open htmlcov/index.html  # Ver reporte visual
```

### 2. Agregar Tests de Go

```bash
cd app/StockWiz/api-gateway

# Crear archivo de test
cat > main_test.go << 'EOF'
package main

import "testing"

func TestSample(t *testing.T) {
    if 1+1 != 2 {
        t.Error("Math is broken")
    }
}
EOF

# Ejecutar
./scripts/run-tests-docker.sh
```

### 3. Tests Funcionales

```bash
# Instalar Newman
npm install -g newman newman-reporter-htmlextra

# Ejecutar contra AWS Dev
./scripts/run-functional-tests.sh dev
```

---

## 📚 Documentación Completa

- **[TESTING_BEST_PRACTICES.md](TESTING_BEST_PRACTICES.md)** - Guía completa de testing
- **[FUNCTIONAL_TESTING.md](FUNCTIONAL_TESTING.md)** - Tests funcionales con Newman
- **[PIPELINE_DEV.md](PIPELINE_DEV.md)** - CI/CD pipeline
- **[README.md](README.md#-testing-local)** - Testing local

---

## ✅ Checklist de Éxito

Ahora puedes:

- [x] Ejecutar tests sin instalar Python/Go
- [x] Ver coverage de código
- [x] Configurar git hook para tests automáticos
- [x] Entender el workflow de testing
- [ ] Mejorar coverage a 80%+ (próximo paso)
- [ ] Agregar tests de Go (próximo paso)
- [ ] Ejecutar tests funcionales (próximo paso)

---

**¿Dudas?** Revisa [TESTING_BEST_PRACTICES.md](TESTING_BEST_PRACTICES.md) o consulta con el equipo.

---
