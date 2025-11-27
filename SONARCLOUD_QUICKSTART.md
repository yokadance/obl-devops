# SonarCloud - Quick Start Guide

Guía rápida para configurar SonarCloud en StockWiz.

## ⚡ Setup Rápido (5 pasos)

### 1️⃣ Crear cuenta en SonarCloud
```
1. Ve a https://sonarcloud.io
2. Click "Log in with GitHub"
3. Autoriza SonarCloud
```

### 2️⃣ Importar proyecto
```
1. Click "+" → "Analyze new project"
2. Selecciona "obl-devops"
3. Click "Set Up" → "With GitHub Actions"
4. Copia: SONAR_TOKEN, SONAR_ORGANIZATION, SONAR_PROJECT_KEY
```

### 3️⃣ Agregar secrets a GitHub
```
Settings → Secrets and variables → Actions → New repository secret

Agregar:
- SONAR_TOKEN: (tu token)
- SONAR_ORGANIZATION: (tu org)
- SONAR_PROJECT_KEY: stockwiz-devops
```

### 4️⃣ Hacer push
```bash
git add .
git commit -m "feat: add SonarCloud integration"
git push
```

### 5️⃣ Ver resultados
```
1. Ve a Actions en GitHub
2. Espera que termine el workflow "SonarCloud Analysis"
3. Ve a https://sonarcloud.io para ver el reporte completo
```

---

## 📊 Quality Gates Configurados

| Métrica | Umbral | Estado |
|---------|--------|--------|
| Coverage | ≥ 80% | ✅ Obligatorio |
| Duplicación | ≤ 3% | ✅ Obligatorio |
| Bugs | 0 en nuevo código | ✅ Obligatorio |
| Vulnerabilities | 0 en nuevo código | ✅ Obligatorio |
| Code Smells | < 5 por 1000 líneas | ✅ Obligatorio |
| Security Rating | A | ✅ Obligatorio |

---

## 🧪 Ejecutar Tests Localmente

### Python (Product Service)
```bash
cd app/StockWiz/product-service
pip install -r requirements.txt
pip install pytest pytest-cov httpx
pytest --cov=. --cov-report=xml --cov-report=term
```

### Go (API Gateway)
```bash
cd app/StockWiz/api-gateway
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -html=coverage.out
```

### Go (Inventory Service)
```bash
cd app/StockWiz/inventory-service
go test -coverprofile=coverage.out -covermode=atomic ./...
go tool cover -html=coverage.out
```

---

## 🔍 Ver Resultados

### En SonarCloud
- Dashboard: https://sonarcloud.io/project/overview?id=stockwiz-devops
- Issues: https://sonarcloud.io/project/issues?id=stockwiz-devops
- Security: https://sonarcloud.io/project/security_hotspots?id=stockwiz-devops

### En GitHub PR
- SonarCloud agregará un check automático
- Click "Details" para ver issues detectados
- El PR muestra: ✅ Quality Gate passed o ❌ Failed

---

## 🛠️ Troubleshooting Rápido

| Error | Solución |
|-------|----------|
| "SONAR_TOKEN not found" | Verifica secrets en GitHub Settings |
| "Quality Gate failed" | Ve a SonarCloud → Issues y arregla los problemas |
| "No coverage report" | Ejecuta tests localmente primero |
| Workflow no se ejecuta | Verifica que modificaste archivos en `app/StockWiz/` |

---

## 📝 Archivos Importantes

```
.
├── .github/workflows/
│   └── sonarcloud.yml           # Workflow de análisis
├── sonar-project.properties     # Configuración de SonarCloud
├── SONARCLOUD_SETUP.md          # Guía completa
└── app/StockWiz/
    ├── product-service/
    │   ├── pytest.ini           # Config de pytest
    │   └── tests/               # Tests de Python
    ├── api-gateway/
    │   └── *_test.go            # Tests de Go
    └── inventory-service/
        └── *_test.go            # Tests de Go
```

---

## ✅ Checklist

- [ ] Cuenta en SonarCloud creada
- [ ] Proyecto importado
- [ ] Secrets configurados en GitHub
- [ ] Push realizado
- [ ] Workflow ejecutado exitosamente
- [ ] Resultados visibles en SonarCloud

---

## 📚 Documentación Completa

Para más detalles, consulta: [SONARCLOUD_SETUP.md](SONARCLOUD_SETUP.md)

---

**¿Necesitas ayuda?** Consulta:
- [SonarCloud Docs](https://docs.sonarcloud.io/)
- [Quality Gates](https://docs.sonarcloud.io/improving/quality-gates/)
- [GitHub Actions Integration](https://docs.sonarcloud.io/getting-started/github/)
