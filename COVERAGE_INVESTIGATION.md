# Investigación: Coverage 0% desde Noviembre 27

## 🔍 Problema Identificado

**El coverage reporta 0% en SonarCloud desde el 27 de noviembre**, aunque antes no era un issue bloqueante.

---

## ✅ Hallazgos Principales

### 1. **SonarCloud se configuró el 27 de Noviembre (19:58)**

Commit `5752f1c` - "feat:sonarqube para chequeo calidad de codigo"
- Se creó `sonar-project.properties`
- Se agregó workflow `.github/workflows/sonarcloud.yml`
- **Primera vez que se configura SonarCloud en el proyecto**

### 2. **Quality Gate Check se habilitó el 27 de Noviembre (21:20)**

Commit `beec92d` - "feat: habilitar quality gate check de sonarcloud"
- Se agregó el check del Quality Gate al pipeline
- **Antes de esto, SonarCloud analizaba pero NO bloqueaba el pipeline**

### 3. **El Coverage SIEMPRE fue 0% - pero antes no se verificaba**

**Evidencia:**

#### Pipeline del 27 de Noviembre configuraba:
```yaml
- name: Run Go tests - API Gateway
  working-directory: app/StockWiz/api-gateway
  run: |
    go mod download
    go test -coverprofile=coverage.out -covermode=atomic ./... || true
    go test -json > test-report.json || true
  continue-on-error: true  # ⚠️ NUNCA FALLA si no hay tests
```

**Resultado actual:**
```bash
$ ls -la app/StockWiz/api-gateway/coverage.out
-rw-r--r-- 1 michaelrodriguez staff 10B Nov 29 01:19 coverage.out

$ cat app/StockWiz/api-gateway/coverage.out
mode: set
```

**Análisis:**
- El archivo `coverage.out` tiene solo 10 bytes: contiene únicamente el header "mode: set"
- **No hay datos de coverage porque NO hay archivos de test**
- El comando `go test ./...` ejecuta exitosamente cuando no hay tests (no es un error)
- Con `continue-on-error: true`, el pipeline sigue aunque el coverage sea vacío

#### SonarCloud configuración:
```properties
# sonar-project.properties (líneas 50-55)
# Python coverage (product-service)
sonar.python.coverage.reportPaths=app/StockWiz/product-service/coverage.xml

# Go coverage (api-gateway, inventory-service)
sonar.go.coverage.reportPaths=\
  app/StockWiz/api-gateway/coverage.out,\
  app/StockWiz/inventory-service/coverage.out
```

**Problema:**
- SonarCloud espera archivos `coverage.out` con datos reales
- Recibe archivos vacíos (solo headers, sin coverage)
- Reporta **Coverage: 0.0%**
- Quality Gate requiere **Coverage ≥ 80%**
- **FALLA** ❌

---

## 📊 Resumen Cronológico

| Fecha | Commit | Evento | Impacto |
|-------|--------|--------|---------|
| **27 Nov 19:58** | `5752f1c` | Se crea configuración de SonarCloud | SonarCloud empieza a escanear código |
| **27 Nov 20:XX** | `95fb6cc` | Fix tests de product-service para CI/CD | Tests de Python funcionan ✅ |
| **27 Nov 20:XX** | `6c3aad4` | Simplificar tests Python | Tests Python OK, pero **Go sigue sin tests** |
| **27 Nov 21:20** | `beec92d` | Habilitar Quality Gate check | **Ahora el pipeline FALLA si QG falla** ❌ |
| **27 Nov 21:XX** | `f235e01` | Comentar QG check (error 403) | Quality Gate temporalmente deshabilitado |
| **29 Nov (hoy)** | - | Quality Gate re-habilitado con API directa | **Ahora SÍ bloquea por Coverage 0%** |

---

## 🎯 Conclusión

### **¿Por qué no pasaba esto el 27 de noviembre?**

**Respuesta:** SÍ pasaba, pero:

1. **27 Nov 19:58**: SonarCloud se configuró por primera vez
2. **27 Nov 21:20**: Quality Gate check se habilitó
3. **27 Nov después**: Quality Gate check se deshabilitó temporalmente (error 403 con token)
4. **29 Nov**: Quality Gate se re-habilitó con API directa de SonarCloud

**El problema de coverage 0% SIEMPRE existió desde que se configuró SonarCloud**, pero:
- Los primeros análisis puede que no hayan tenido tiempo de procesar
- El Quality Gate estuvo comentado/deshabilitado temporalmente
- **Nunca hubo un momento donde los servicios Go tuvieran tests**

### **Estado Actual vs Estado del 27 Nov**

| Aspecto | 27 Noviembre | Hoy (29 Nov) |
|---------|--------------|--------------|
| **SonarCloud configurado** | ✅ Sí (desde 19:58) | ✅ Sí |
| **Quality Gate habilitado** | ⚠️ Deshabilitado (error 403) | ✅ Habilitado (API directa) |
| **Tests Python** | ✅ Funcionando | ✅ Funcionando |
| **Tests Go** | ❌ No existen | ❌ No existen |
| **Coverage reportado** | 0% (no verificado) | 0% (VERIFICADO y BLOQUEANTE) |
| **Pipeline bloquea por coverage** | ❌ No (QG deshabilitado) | ✅ SÍ (QG habilitado) |

---

## 🔧 Soluciones Posibles

### Opción 1: Crear Tests para Go (Recomendado para producción)
- Crear `main_test.go` para api-gateway
- Crear `main_test.go` para inventory-service
- Alcanzar ≥80% coverage
- **Tiempo estimado:** Considerable (requiere mocks de Redis, PostgreSQL, etc.)

### Opción 2: Ajustar Threshold de Coverage en SonarCloud
- Ir a SonarCloud → Project Settings → Quality Gates
- Reducir el threshold de coverage (ej: de 80% a 10%)
- **Impacto:** Reduce la calidad de código requerida

### Opción 3: Excluir servicios Go del análisis de coverage
Modificar `sonar-project.properties`:
```properties
# Comentar las rutas de coverage de Go
# sonar.go.coverage.reportPaths=\
#   app/StockWiz/api-gateway/coverage.out,\
#   app/StockWiz/inventory-service/coverage.out
```
**Impacto:** SonarCloud no verifica coverage de Go, solo de Python

### Opción 4: Deshabilitar Quality Gate temporalmente
En `.github/workflows/dev-pipeline.yml`, cambiar:
```yaml
if [ "$QUALITY_GATE_STATUS" = "ERROR" ]; then
  echo "✗ Quality Gate failed"
  exit 0  # Cambiar exit 1 a exit 0 para no bloquear
```
**Impacto:** El pipeline no falla, pero SonarCloud seguirá mostrando el error

---

## 📝 Archivos Relacionados

- [sonar-project.properties](sonar-project.properties) - Configuración de SonarCloud
- [.github/workflows/dev-pipeline.yml](.github/workflows/dev-pipeline.yml#L60-L75) - Pipeline con Go tests
- [SONARCLOUD_STATUS.md](SONARCLOUD_STATUS.md) - Estado del Quality Gate actual
- [SECURITY_SETUP.md](SECURITY_SETUP.md) - Cambios de seguridad (passwords)

---

**Fecha:** 2025-11-29
**Issue:** Coverage 0% desde configuración inicial de SonarCloud (27 Nov)
**Causa raíz:** Servicios Go nunca tuvieron tests, Quality Gate ahora está habilitado
**Solución anterior:** Issue de seguridad (passwords) RESUELTO ✅
**Solución pendiente:** Coverage < 80% requiere crear tests Go o ajustar configuración
