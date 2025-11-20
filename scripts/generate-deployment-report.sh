#!/bin/bash

# ============================================
# Generador de reporte HTML de despliegue
# ============================================
# Este script genera una página HTML con información
# del despliegue y la abre en el navegador
#
# Uso:
#   ./scripts/generate-deployment-report.sh [environment]
#
# Parámetros:
#   environment: dev, stage, prod (default: dev)

set -e

ENVIRONMENT=${1:-dev}
TERRAFORM_DIR="IaC/terraform/environments/${ENVIRONMENT}"
REPORT_FILE="deployment-report-${ENVIRONMENT}.html"

# Colores para output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Generando reporte de despliegue para ${ENVIRONMENT}...${NC}"

# Obtener outputs de Terraform
ALB_DNS=$(terraform -chdir=${TERRAFORM_DIR} output -raw alb_dns_name 2>/dev/null || echo "N/A")
API_GATEWAY_ECR=$(terraform -chdir=${TERRAFORM_DIR} output -raw api_gateway_ecr_url 2>/dev/null || echo "N/A")
PRODUCT_SERVICE_ECR=$(terraform -chdir=${TERRAFORM_DIR} output -raw product_service_ecr_url 2>/dev/null || echo "N/A")
INVENTORY_SERVICE_ECR=$(terraform -chdir=${TERRAFORM_DIR} output -raw inventory_service_ecr_url 2>/dev/null || echo "N/A")
POSTGRES_ECR=$(terraform -chdir=${TERRAFORM_DIR} output -raw postgres_ecr_url 2>/dev/null || echo "N/A")

# Verificar health check
HEALTH_STATUS="Checking..."
HEALTH_COLOR="orange"
if [ "$ALB_DNS" != "N/A" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/health" --connect-timeout 5 || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        HEALTH_STATUS="Healthy ✓"
        HEALTH_COLOR="green"
    else
        HEALTH_STATUS="Unhealthy (HTTP $HTTP_CODE)"
        HEALTH_COLOR="red"
    fi
fi

# Obtener timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Generar HTML
cat > ${REPORT_FILE} << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>StockWiz Deployment Report - ${ENVIRONMENT}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .environment-badge {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            padding: 8px 20px;
            border-radius: 20px;
            font-size: 1.1em;
            margin-top: 10px;
            text-transform: uppercase;
            font-weight: bold;
        }

        .content {
            padding: 40px;
        }

        .section {
            margin-bottom: 30px;
            border-left: 4px solid #667eea;
            padding-left: 20px;
        }

        .section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5em;
        }

        .info-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
            transition: transform 0.2s;
        }

        .info-card:hover {
            transform: translateX(5px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }

        .info-card h3 {
            color: #333;
            margin-bottom: 10px;
            font-size: 1.2em;
        }

        .info-card p {
            color: #666;
            word-break: break-all;
            line-height: 1.6;
        }

        .health-status {
            display: inline-flex;
            align-items: center;
            padding: 10px 20px;
            border-radius: 25px;
            font-weight: bold;
            font-size: 1.1em;
        }

        .health-green {
            background: #d4edda;
            color: #155724;
        }

        .health-red {
            background: #f8d7da;
            color: #721c24;
        }

        .health-orange {
            background: #fff3cd;
            color: #856404;
        }

        .button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 30px;
            border-radius: 25px;
            text-decoration: none;
            margin: 5px;
            transition: transform 0.2s, box-shadow 0.2s;
            font-weight: bold;
        }

        .button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }

        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #ddd;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }

        .timestamp {
            text-align: center;
            color: #666;
            font-style: italic;
            margin-top: 10px;
        }

        code {
            background: #f1f3f5;
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 StockWiz Deployment Report</h1>
                <h2>📚 Obligatorio DevOps - ORT - </h2>

            <div class="environment-badge">${ENVIRONMENT} Environment</div>
            <p class="timestamp">Generated: ${TIMESTAMP}</p>
        </div>

        <div class="content">
            <!-- Health Status Section -->
            <div class="section">
                <h2>🏥 Health Status</h2>
                <div class="info-card">
                    <span class="health-status health-${HEALTH_COLOR}">${HEALTH_STATUS}</span>
                </div>
            </div>

            <!-- Load Balancer Section -->
            <div class="section">
                <h2>🌐 Application Load Balancer</h2>
                <div class="info-card">
                    <h3>ALB DNS Name</h3>
                    <p><code>${ALB_DNS}</code></p>
                    <div style="margin-top: 15px;">
                        <a href="http://${ALB_DNS}/health" target="_blank" class="button">Health Check</a>
                        <a href="http://${ALB_DNS}/api/products" target="_blank" class="button">Products API</a>
                        <a href="http://${ALB_DNS}/api/inventory" target="_blank" class="button">Inventory API</a>
                    </div>
                </div>
            </div>

            <!-- ECR Repositories Section -->
            <div class="section">
                <h2>📦 ECR Repositories</h2>
                <div class="grid">
                    <div class="info-card">
                        <h3>API Gateway</h3>
                        <p><code>${API_GATEWAY_ECR}</code></p>
                    </div>
                    <div class="info-card">
                        <h3>Product Service</h3>
                        <p><code>${PRODUCT_SERVICE_ECR}</code></p>
                    </div>
                    <div class="info-card">
                        <h3>Inventory Service</h3>
                        <p><code>${INVENTORY_SERVICE_ECR}</code></p>
                    </div>
                    <div class="info-card">
                        <h3>PostgreSQL</h3>
                        <p><code>${POSTGRES_ECR}</code></p>
                    </div>
                </div>
            </div>

            <!-- Quick Commands Section -->
            <div class="section">
                <h2>⚡ Quick Commands</h2>
                <div class="info-card">
                    <h3>Check Health</h3>
                    <p><code>curl http://${ALB_DNS}/health</code></p>
                </div>
                <div class="info-card">
                    <h3>View ECS Services</h3>
                    <p><code>aws ecs list-services --cluster stockwiz-${ENVIRONMENT}</code></p>
                </div>
                <div class="info-card">
                    <h3>View Logs</h3>
                    <p><code>aws logs tail /ecs/stockwiz-${ENVIRONMENT} --follow</code></p>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>StockWiz - DevOps Team</p>
            <p>Managed by Terraform | Environment: ${ENVIRONMENT}</p>
        </div>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}✓ Reporte generado: ${REPORT_FILE}${NC}"
echo -e "${CYAN}Abriendo en el navegador...${NC}"

# Abrir en el navegador según el sistema operativo
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open ${REPORT_FILE}
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open ${REPORT_FILE} 2>/dev/null || sensible-browser ${REPORT_FILE} 2>/dev/null
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    start ${REPORT_FILE}
else
    echo "Por favor abre manualmente: ${REPORT_FILE}"
fi

echo -e "${GREEN}✓ Listo!${NC}"
