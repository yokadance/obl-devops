import json
import os
import urllib3
import time
import boto3
import random
from datetime import datetime, timedelta

# Cliente de CloudWatch
cloudwatch = boto3.client('cloudwatch')

# Crear pool HTTP
http = urllib3.PoolManager(
    timeout=urllib3.Timeout(connect=5.0, read=10.0),
    retries=urllib3.Retry(3, redirect=2)
)

def lambda_handler(event, context):
    """
    Lambda function que verifica el health de los servicios
    """
    alb_dns = os.environ.get('ALB_DNS_NAME', '')
    environment = os.environ.get('ENVIRONMENT', 'dev')

    # Detectar si es una prueba de falla simulada
    simulate_failure = event.get('simulate_failure', False) if event else False
    failure_type = event.get('failure_type', 'database') if event else 'database'

    if simulate_failure:
        print(f"⚠️ MODO TEST: Simulando falla de {failure_type}")
        # Enviar métricas de falla simulada y terminar
        send_simulated_failure_metrics(environment, failure_type)
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Simulación de falla: {failure_type}',
                'environment': environment,
                'timestamp': datetime.now().isoformat()
            })
        }

    if not alb_dns:
        print("ERROR: ALB_DNS_NAME no esta configurado")
        return {
            'statusCode': 500,
            'body': json.dumps('ALB_DNS_NAME no configurado')
        }

    print(f"Verificando health para ALB: {alb_dns} en ambiente: {environment}")

    # Resultados de los checks
    results = {
        'timestamp': datetime.now().isoformat(),
        'environment': environment,
        'checks': []
    }

    # 1. Check HTTP (puerto 80)
    http_check = check_endpoint(
        url=f"http://{alb_dns}/health",
        name="HTTP",
        port=80
    )
    results['checks'].append(http_check)

    # 2. Check HTTPS (puerto 443)
    # Nota: Solo si tienes certificado SSL configurado
    https_check = check_endpoint(
        url=f"https://{alb_dns}/health",
        name="HTTPS",
        port=443
    )
    results['checks'].append(https_check)

    # 3. Check API Gateway endpoint
    api_gw_check = check_endpoint(
        url=f"http://{alb_dns}/",
        name="APIGateway",
        port=80
    )
    results['checks'].append(api_gw_check)

    # 4. Check productos endpoint
    products_check = check_endpoint(
        url=f"http://{alb_dns}/api/products",
        name="Products",
        port=80
    )
    results['checks'].append(products_check)

    # 5. Check inventario endpoint
    inventory_check = check_endpoint(
        url=f"http://{alb_dns}/api/inventory",
        name="Inventory",
        port=80
    )
    results['checks'].append(inventory_check)

    # Enviar metricas a CloudWatch
    send_metrics_to_cloudwatch(results, environment)

    # Si es dev, generar datos aleatorios adicionales para las graficas
    if environment == 'dev':
        generate_random_metrics(environment)

    # Log de resultados
    print(json.dumps(results, indent=2))

    # Determinar status general
    all_healthy = all(check['healthy'] for check in results['checks'])

    return {
        'statusCode': 200 if all_healthy else 500,
        'body': json.dumps(results)
    }

def check_endpoint(url, name, port):
    """
    Verifica un endpoint especifico
    """
    result = {
        'name': name,
        'url': url,
        'port': port,
        'healthy': False,
        'status_code': None,
        'response_time_ms': None,
        'error': None
    }

    try:
        start_time = time.time()

        # Hacer request
        response = http.request('GET', url)

        # Calcular response time
        response_time = (time.time() - start_time) * 1000  # en milisegundos

        result['status_code'] = response.status
        result['response_time_ms'] = round(response_time, 2)

        # Consideramos healthy si status es 200-299
        if 200 <= response.status < 300:
            result['healthy'] = True
            print(f"✓ {name} OK - {response.status} - {result['response_time_ms']}ms")
        else:
            print(f"✗ {name} FAILED - Status: {response.status}")
            result['error'] = f"HTTP {response.status}"

    except urllib3.exceptions.SSLError as e:
        # Si falla HTTPS (normal si no hay certificado SSL)
        print(f"✗ {name} SSL Error (esperado si no hay certificado): {str(e)}")
        result['error'] = "SSL not configured"
        result['healthy'] = False

    except Exception as e:
        print(f"✗ {name} ERROR: {str(e)}")
        result['error'] = str(e)
        result['healthy'] = False

    return result

def send_simulated_failure_metrics(environment, failure_type):
    """
    Envía métricas simulando una falla para pruebas de alarmas
    Envía múltiples puntos de datos (últimos 15 minutos) para activar alarmas más rápido
    """
    namespace = f"StockWiz/{environment}"

    print(f"📊 Enviando métricas de falla simulada: {failure_type}")
    print(f"Generando puntos de datos para los últimos 15 minutos...")

    metric_data = []

    # Generar métricas para los últimos 15 minutos (3 períodos de 5 minutos)
    # Esto ayuda a activar alarmas que requieren 2+ períodos consecutivos
    for minutes_ago in [15, 10, 5, 0]:
        timestamp = datetime.utcnow() - timedelta(minutes=minutes_ago)

        if failure_type == 'database':
            # Simular falla de base de datos
            metric_data.extend([
                {
                    'MetricName': 'HealthCheck-HTTP',
                    'Value': 0.0,  # Falla
                    'Unit': 'None',
                    'Timestamp': timestamp,
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': environment},
                        {'Name': 'Port', 'Value': '80'}
                    ]
                },
                {
                    'MetricName': 'HealthCheck-HTTPS',
                    'Value': 0.0,  # Falla
                    'Unit': 'None',
                    'Timestamp': timestamp,
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': environment},
                        {'Name': 'Port', 'Value': '443'}
                    ]
                },
                {
                    'MetricName': 'ResponseTime-HTTP',
                    'Value': 5000.0,  # Timeout simulado
                    'Unit': 'Milliseconds',
                    'Timestamp': timestamp,
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': environment},
                        {'Name': 'Port', 'Value': '80'}
                    ]
                }
            ])
        elif failure_type == 'high_cpu':
            # Simular alto CPU
            metric_data.append({
                'MetricName': 'SimulatedCPU',
                'Value': 95.0,
                'Unit': 'Percent',
                'Timestamp': timestamp,
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            })
        elif failure_type == 'high_memory':
            # Simular alta memoria
            metric_data.append({
                'MetricName': 'SimulatedMemory',
                'Value': 95.0,
                'Unit': 'Percent',
                'Timestamp': timestamp,
                'Dimensions': [{'Name': 'Environment', 'Value': environment}]
            })
        elif failure_type == 'slow_response':
            # Simular respuestas lentas
            for service in ['HTTP', 'HTTPS', 'APIGateway']:
                metric_data.append({
                    'MetricName': f"ResponseTime-{service}",
                    'Value': 8000.0,  # 8 segundos
                    'Unit': 'Milliseconds',
                    'Timestamp': timestamp,
                    'Dimensions': [
                        {'Name': 'Environment', 'Value': environment},
                        {'Name': 'Port', 'Value': '80'}
                    ]
                })

    # Enviar métricas
    if metric_data:
        try:
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=metric_data
            )
            print(f"✓ Enviadas {len(metric_data)} métricas de falla simulada a CloudWatch")
            print(f"Namespace: {namespace}")
            print(f"Períodos cubiertos: últimos 15 minutos (4 puntos de tiempo)")
            # Mostrar resumen de métricas (no todas)
            metric_names = set(m['MetricName'] for m in metric_data)
            print(f"Métricas enviadas: {', '.join(metric_names)}")
        except Exception as e:
            print(f"✗ Error enviando métricas de falla: {str(e)}")

def send_metrics_to_cloudwatch(results, environment):
    """
    Envia metricas a CloudWatch
    """
    namespace = f"StockWiz/{environment}"
    timestamp = datetime.utcnow()

    metric_data = []

    for check in results['checks']:
        # Metrica de health (1 = healthy salud ok, 0 = unhealthy salud no ok)
        metric_data.append({
            'MetricName': f"HealthCheck-{check['name']}",
            'Value': 1.0 if check['healthy'] else 0.0,
            'Unit': 'None',
            'Timestamp': timestamp,
            'Dimensions': [
                {'Name': 'Environment', 'Value': environment},
                {'Name': 'Port', 'Value': str(check['port'])}
            ]
        })

        # Metrica de response time (solo si hay)
        if check['response_time_ms'] is not None:
            metric_data.append({
                'MetricName': f"ResponseTime-{check['name']}",
                'Value': check['response_time_ms'],
                'Unit': 'Milliseconds',
                'Timestamp': timestamp,
                'Dimensions': [
                    {'Name': 'Environment', 'Value': environment},
                    {'Name': 'Port', 'Value': str(check['port'])}
                ]
            })

    # Enviar todas las metricas de una vez
    if metric_data:
        try:
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=metric_data
            )
            print(f"✓ Enviadas {len(metric_data)} metricas a CloudWatch")
        except Exception as e:
            print(f"✗ Error enviando metricas a CloudWatch: {str(e)}")


###SIMULACION DE DATOS

def generate_random_metrics(environment):
    """
    Genera metricas aleatorias para ambiente dev (para visualizacion en graficas)
    """
    namespace = f"StockWiz/{environment}"
    timestamp = datetime.utcnow()

    print("📊 Generando metricas aleatorias para dev...")

    metric_data = []

    # Simular CPU y Memory fluctuantes
    metric_data.append({
        'MetricName': 'SimulatedCPU',
        'Value': random.uniform(20, 85),
        'Unit': 'Percent',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    metric_data.append({
        'MetricName': 'SimulatedMemory',
        'Value': random.uniform(30, 75),
        'Unit': 'Percent',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Simular requests count (variando entre 10 y 200 requests)
    metric_data.append({
        'MetricName': 'SimulatedRequestCount',
        'Value': random.randint(10, 200),
        'Unit': 'Count',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Simular response times
    for service in ['HTTP', 'HTTPS', 'APIGateway', 'Products', 'Inventory']:
        metric_data.append({
            'MetricName': f"SimulatedResponseTime-{service}",
            'Value': random.uniform(50, 500),
            'Unit': 'Milliseconds',
            'Timestamp': timestamp,
            'Dimensions': [
                {'Name': 'Environment', 'Value': environment},
                {'Name': 'Service', 'Value': service}
            ]
        })

    # Simular HTTP status codes
    # Mas 2XX (exitosos)
    metric_data.append({
        'MetricName': 'Simulated2XXCount',
        'Value': random.randint(80, 150),
        'Unit': 'Count',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Algunos 4XX (errores de cliente)
    metric_data.append({
        'MetricName': 'Simulated4XXCount',
        'Value': random.randint(0, 15),
        'Unit': 'Count',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Pocos 5XX (errores de servidor)
    metric_data.append({
        'MetricName': 'Simulated5XXCount',
        'Value': random.randint(0, 5),
        'Unit': 'Count',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Simular database connections
    metric_data.append({
        'MetricName': 'SimulatedDBConnections',
        'Value': random.randint(5, 50),
        'Unit': 'Count',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Simular cache hit rate (70-95%)
    metric_data.append({
        'MetricName': 'SimulatedCacheHitRate',
        'Value': random.uniform(70, 95),
        'Unit': 'Percent',
        'Timestamp': timestamp,
        'Dimensions': [{'Name': 'Environment', 'Value': environment}]
    })

    # Enviar metricas
    try:
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=metric_data
        )
        print(f"✓ Enviadas {len(metric_data)} metricas aleatorias a CloudWatch")
    except Exception as e:
        print(f"✗ Error enviando metricas aleatorias: {str(e)}")
