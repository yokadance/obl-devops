"""
Tests básicos para Product Service
"""
import pytest
import os

# Configurar variables de entorno ANTES de importar main
os.environ["SKIP_DATABASE"] = "true"
os.environ["SKIP_REDIS"] = "true"


def test_environment_variables():
    """Test que las variables de entorno están configuradas"""
    assert os.getenv("SKIP_DATABASE") == "true"
    assert os.getenv("SKIP_REDIS") == "true"


def test_import_main():
    """Test que podemos importar el módulo main"""
    try:
        from main import app
        assert app is not None
        assert app.title == "Product Service"
    except Exception as e:
        pytest.fail(f"Failed to import main: {e}")


def test_app_routes():
    """Test que la app tiene las rutas esperadas"""
    from main import app

    routes = [route.path for route in app.routes]
    assert "/health" in routes
    assert "/products" in routes
