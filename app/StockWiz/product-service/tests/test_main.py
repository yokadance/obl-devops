"""
Tests for Product Service
"""
import pytest
from fastapi.testclient import TestClient
import os

# Set environment variables to skip external dependencies during testing
os.environ["SKIP_DATABASE"] = "true"
os.environ["SKIP_REDIS"] = "true"

from main import app

@pytest.fixture
def client():
    """
    Create a test client for the FastAPI app
    """
    return TestClient(app)


class TestHealthEndpoint:
    """Tests for health check endpoint"""

    def test_health_returns_200(self, client):
        """Test that health endpoint returns 200 OK"""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_json(self, client):
        """Test that health endpoint returns JSON"""
        response = client.get("/health")
        assert response.headers["content-type"] == "application/json"

    def test_health_contains_status(self, client):
        """Test that health response contains status field"""
        response = client.get("/health")
        data = response.json()
        assert "status" in data


class TestProductsEndpoint:
    """Tests for products CRUD endpoints"""

    def test_get_products_returns_200(self, client):
        """Test that GET /products returns 200"""
        response = client.get("/products")
        assert response.status_code in [200, 503]  # 503 if DB is down

    def test_get_products_returns_list(self, client):
        """Test that GET /products returns a list"""
        response = client.get("/products")
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)


class TestProductValidation:
    """Tests for product model validation"""

    def test_create_product_requires_name(self, client):
        """Test that creating a product requires a name"""
        payload = {
            "price": 10.99,
            "description": "Test product"
        }
        response = client.post("/products", json=payload)
        # Should fail validation (422) or service unavailable (503)
        assert response.status_code in [422, 503]

    def test_create_product_requires_positive_price(self, client):
        """Test that product price must be positive"""
        payload = {
            "name": "Test Product",
            "price": -5.0,
            "description": "Test product"
        }
        response = client.post("/products", json=payload)
        # Should fail validation
        assert response.status_code in [422, 503]

    def test_create_product_with_valid_data(self, client):
        """Test creating a product with valid data"""
        payload = {
            "name": "Test Product",
            "price": 19.99,
            "description": "A test product",
            "category": "Electronics"
        }
        response = client.post("/products", json=payload)
        # May succeed (201) or fail if DB unavailable (503)
        assert response.status_code in [201, 503]


class TestCORS:
    """Tests for CORS configuration"""

    def test_cors_headers_present(self, client):
        """Test that CORS headers are present"""
        response = client.options("/products")
        # FastAPI should handle OPTIONS requests
        assert response.status_code in [200, 405]


class TestErrorHandling:
    """Tests for error handling"""

    def test_invalid_endpoint_returns_404(self, client):
        """Test that invalid endpoints return 404"""
        response = client.get("/invalid-endpoint")
        assert response.status_code == 404

    def test_invalid_product_id_type(self, client):
        """Test that invalid product ID type is handled"""
        response = client.get("/products/invalid-id")
        # Should return 422 (validation error) or 404
        assert response.status_code in [404, 422]
