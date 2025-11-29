package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"
	"github.com/go-chi/chi/v5"
	"github.com/go-redis/redis/v8"
)

// MockHTTPClient es un cliente HTTP mock para testing
type MockHTTPClient struct {
	DoFunc func(req *http.Request) (*http.Response, error)
}

func (m *MockHTTPClient) Do(req *http.Request) (*http.Response, error) {
	if m.DoFunc != nil {
		return m.DoFunc(req)
	}
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
	}, nil
}

func (m *MockHTTPClient) Get(url string) (*http.Response, error) {
	req, _ := http.NewRequest("GET", url, nil)
	return m.Do(req)
}

// setupTestServer crea un servidor de prueba con dependencias mockeadas
func setupTestServer(t *testing.T) *Server {
	// Setup Redis client mock (usaremos miniredis para testing sin dependencias)
	// Por ahora usaremos un cliente que apunte a una DB que no existe
	redisClient := redis.NewClient(&redis.Options{
		Addr: "localhost:63799", // Puerto que probablemente no existe
		DB:   15,
	})

	// Setup HTTP client mock
	httpClient := &MockHTTPClient{}

	// Setup filesystem mock
	mockFS := fstest.MapFS{
		"static/index.html": &fstest.MapFile{
			Data: []byte("<html><body>Test Page</body></html>"),
		},
	}

	server := NewServer(
		"http://product-service:8001",
		"http://inventory-service:8002",
		redisClient,
		httpClient,
		mockFS,
	)

	return server
}

func TestHealthCheck(t *testing.T) {
	server := setupTestServer(t)

	// Mock HTTP client para simular servicios downstream
	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			if strings.Contains(req.URL.String(), "product-service") {
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBufferString(`{"status":"healthy"}`)),
				}, nil
			}
			if strings.Contains(req.URL.String(), "inventory-service") {
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBufferString(`{"status":"healthy"}`)),
				}, nil
			}
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	server.HealthCheck(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Errorf("Failed to decode response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got %v", response["status"])
	}
}

func TestHealthCheckWithUnhealthyServices(t *testing.T) {
	server := setupTestServer(t)

	// Mock HTTP client para simular servicios caídos
	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusServiceUnavailable,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	server.HealthCheck(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Errorf("Failed to decode response: %v", err)
	}

	downstreamServices := response["downstream_services"].(map[string]interface{})
	if downstreamServices["product_service"] != "unhealthy" {
		t.Errorf("Expected product_service to be unhealthy")
	}
	if downstreamServices["inventory_service"] != "unhealthy" {
		t.Errorf("Expected inventory_service to be unhealthy")
	}
}

func TestServeIndex(t *testing.T) {
	server := setupTestServer(t)

	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()

	server.ServeIndex(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	if !strings.Contains(w.Body.String(), "Test Page") {
		t.Errorf("Expected response to contain 'Test Page'")
	}

	if w.Header().Get("Content-Type") != "text/html" {
		t.Errorf("Expected Content-Type text/html, got %s", w.Header().Get("Content-Type"))
	}
}

func TestServeIndexError(t *testing.T) {
	redisClient := redis.NewClient(&redis.Options{Addr: "localhost:63799", DB: 15})

	emptyFS := fstest.MapFS{}
	server := NewServer(
		"http://product-service:8001",
		"http://inventory-service:8002",
		redisClient,
		&MockHTTPClient{},
		emptyFS,
	)

	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()

	server.ServeIndex(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500, got %d", w.Code)
	}
}

func TestGetProductWithInventory(t *testing.T) {
	server := setupTestServer(t)

	productResponse := ProductWithInventory{
		ID:          1,
		Name:        "Test Product",
		Description: stringPtr("Test Description"),
		Price:       99.99,
		Category:    stringPtr("Test Category"),
	}

	inventoryResponse := map[string]interface{}{
		"quantity":  10,
		"warehouse": "Main Warehouse",
	}

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			if strings.Contains(req.URL.String(), "/products/1") {
				body, _ := json.Marshal(productResponse)
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBuffer(body)),
				}, nil
			}
			if strings.Contains(req.URL.String(), "/inventory/product/1") {
				body, _ := json.Marshal(inventoryResponse)
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBuffer(body)),
				}, nil
			}
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/products/1", nil)
	w := httptest.NewRecorder()

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))

	server.GetProductWithInventory(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response ProductWithInventory
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Errorf("Failed to decode response: %v", err)
	}

	if response.ID != 1 {
		t.Errorf("Expected ID 1, got %d", response.ID)
	}
	if response.Name != "Test Product" {
		t.Errorf("Expected name 'Test Product', got %s", response.Name)
	}
	if response.Inventory == nil {
		t.Error("Expected inventory to be present")
	} else if response.Inventory.Quantity != 10 {
		t.Errorf("Expected inventory quantity 10, got %d", response.Inventory.Quantity)
	}
}

func TestGetAllProductsWithInventory(t *testing.T) {
	server := setupTestServer(t)

	products := []ProductWithInventory{
		{ID: 1, Name: "Product 1", Price: 10.00},
		{ID: 2, Name: "Product 2", Price: 20.00},
	}

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			if strings.Contains(req.URL.String(), "/products") && !strings.Contains(req.URL.String(), "/inventory") {
				body, _ := json.Marshal(products)
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBuffer(body)),
				}, nil
			}
			// Simular que no hay inventario
			return &http.Response{
				StatusCode: http.StatusNotFound,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/products-full", nil)
	w := httptest.NewRecorder()

	server.GetAllProductsWithInventory(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response []ProductWithInventory
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Errorf("Failed to decode response: %v", err)
	}

	if len(response) != 2 {
		t.Errorf("Expected 2 products, got %d", len(response))
	}
}

func TestProxyRequest(t *testing.T) {
	server := setupTestServer(t)

	expectedResponse := `{"data":"test"}`

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			if req.Method != "GET" {
				t.Errorf("Expected GET method, got %s", req.Method)
			}
			if !strings.Contains(req.URL.String(), "/products") {
				t.Errorf("Expected URL to contain /products, got %s", req.URL.String())
			}

			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(expectedResponse)),
				Header: http.Header{
					"Content-Type": []string{"application/json"},
				},
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/products", nil)
	w := httptest.NewRecorder()

	server.ProxyToProductService(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
	if w.Body.String() != expectedResponse {
		t.Errorf("Expected body %s, got %s", expectedResponse, w.Body.String())
	}
}

func TestCheckServiceHealth(t *testing.T) {
	server := setupTestServer(t)

	tests := []struct {
		name           string
		statusCode     int
		expectedHealth string
	}{
		{"Healthy Service", http.StatusOK, "healthy"},
		{"Unhealthy Service", http.StatusServiceUnavailable, "unhealthy"},
		{"Server Error", http.StatusInternalServerError, "unhealthy"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := &MockHTTPClient{
				DoFunc: func(req *http.Request) (*http.Response, error) {
					return &http.Response{
						StatusCode: tt.statusCode,
						Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
					}, nil
				},
			}
			server.HTTPClient = mockClient

			health := server.checkServiceHealth("http://test-service/health")
			if health != tt.expectedHealth {
				t.Errorf("Expected %s, got %s", tt.expectedHealth, health)
			}
		})
	}
}

func TestSendError(t *testing.T) {
	server := setupTestServer(t)

	w := httptest.NewRecorder()
	server.sendError(w, http.StatusBadRequest, "Test Error", "Error details")

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}

	if w.Header().Get("Content-Type") != "application/json" {
		t.Errorf("Expected Content-Type application/json")
	}

	var errorResp ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&errorResp); err != nil {
		t.Errorf("Failed to decode error response: %v", err)
	}

	if errorResp.Error != "Test Error" {
		t.Errorf("Expected error 'Test Error', got %s", errorResp.Error)
	}
	if errorResp.Message != "Error details" {
		t.Errorf("Expected message 'Error details', got %s", errorResp.Message)
	}
}

func TestGetEnv(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue string
		envValue     string
		expected     string
	}{
		{"With env set", "TEST_VAR", "default", "custom", "custom"},
		{"Without env set", "NONEXISTENT_VAR_12345", "default", "", "default"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				t.Setenv(tt.key, tt.envValue)
			}
			result := getEnv(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, result)
			}
		})
	}
}

func TestSetupRouter(t *testing.T) {
	server := setupTestServer(t)
	mockFS := fstest.MapFS{}

	router := setupRouter(server, mockFS)

	if router == nil {
		t.Error("Expected router to be initialized")
	}

	// Verificar que tiene rutas configuradas
	routes := router.Routes()
	if len(routes) == 0 {
		t.Error("Expected router to have routes configured")
	}
}

func TestProxyToInventoryService(t *testing.T) {
	server := setupTestServer(t)

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(`{"inventory":"data"}`)),
				Header: http.Header{
					"Content-Type": []string{"application/json"},
				},
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/inventory", nil)
	w := httptest.NewRecorder()

	server.ProxyToInventoryService(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestProductWithInventoryNoInventory(t *testing.T) {
	server := setupTestServer(t)

	productResponse := ProductWithInventory{
		ID:    1,
		Name:  "Test Product",
		Price: 99.99,
	}

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			if strings.Contains(req.URL.String(), "/products/1") {
				body, _ := json.Marshal(productResponse)
				return &http.Response{
					StatusCode: http.StatusOK,
					Body:       io.NopCloser(bytes.NewBuffer(body)),
				}, nil
			}
			// No hay inventario
			return &http.Response{
				StatusCode: http.StatusNotFound,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/products/1", nil)
	w := httptest.NewRecorder()

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))

	server.GetProductWithInventory(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response ProductWithInventory
	json.NewDecoder(w.Body).Decode(&response)

	if response.Inventory != nil {
		t.Error("Expected inventory to be nil when not found")
	}
}

func TestGetAllProductsWithInventoryForceRefresh(t *testing.T) {
	server := setupTestServer(t)

	products := []ProductWithInventory{
		{ID: 1, Name: "New Product", Price: 10.00},
	}

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			body, _ := json.Marshal(products)
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBuffer(body)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	req := httptest.NewRequest("GET", "/api/products-full?force_refresh=true", nil)
	w := httptest.NewRecorder()

	server.GetAllProductsWithInventory(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response []ProductWithInventory
	json.NewDecoder(w.Body).Decode(&response)

	if len(response) != 1 {
		t.Errorf("Expected 1 product, got %d", len(response))
	}
	if response[0].Name != "New Product" {
		t.Errorf("Expected 'New Product', got %s", response[0].Name)
	}
}

// Helper functions
func stringPtr(s string) *string {
	return &s
}

// Mock para verificar que el servidor compila correctamente
func TestServerCompiles(t *testing.T) {
	server := setupTestServer(t)
	if server == nil {
		t.Error("Server should not be nil")
	}
	if server.ProductServiceURL == "" {
		t.Error("ProductServiceURL should be set")
	}
	if server.InventoryServiceURL == "" {
		t.Error("InventoryServiceURL should be set")
	}
}
