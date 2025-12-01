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
	redisClient := redis.NewClient(&redis.Options{
		Addr: "localhost:63799", // Puerto que no existe para evitar dependencias
		DB:   15,
	})

	httpClient := &MockHTTPClient{}

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

func TestNewServer(t *testing.T) {
	server := setupTestServer(t)

	if server == nil {
		t.Fatal("Server should not be nil")
	}
	if server.ProductServiceURL != "http://product-service:8001" {
		t.Errorf("Expected ProductServiceURL to be set")
	}
	if server.InventoryServiceURL != "http://inventory-service:8002" {
		t.Errorf("Expected InventoryServiceURL to be set")
	}
	if server.HTTPClient == nil {
		t.Error("HTTPClient should not be nil")
	}
	if server.RedisClient == nil {
		t.Error("RedisClient should not be nil")
	}
}

func TestHealthCheckHandler(t *testing.T) {
	server := setupTestServer(t)

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(`{"status":"healthy"}`)),
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
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got %v", response["status"])
	}
	if response["service"] != "api-gateway" {
		t.Errorf("Expected service 'api-gateway', got %v", response["service"])
	}
}

func TestCheckServiceHealthy(t *testing.T) {
	server := setupTestServer(t)

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	health := server.checkServiceHealth("http://test-service/health")
	if health != "healthy" {
		t.Errorf("Expected 'healthy', got %s", health)
	}
}

func TestCheckServiceUnhealthy(t *testing.T) {
	server := setupTestServer(t)

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: http.StatusServiceUnavailable,
				Body:       io.NopCloser(bytes.NewBufferString(`{}`)),
			}, nil
		},
	}
	server.HTTPClient = mockClient

	health := server.checkServiceHealth("http://test-service/health")
	if health != "unhealthy" {
		t.Errorf("Expected 'unhealthy', got %s", health)
	}
}

func TestServeIndexSuccess(t *testing.T) {
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

func TestServeIndexFileNotFound(t *testing.T) {
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

func TestGetProductWithInventorySuccess(t *testing.T) {
	server := setupTestServer(t)

	productResponse := ProductWithInventory{
		ID:    1,
		Name:  "Test Product",
		Price: 99.99,
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
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.ID != 1 {
		t.Errorf("Expected ID 1, got %d", response.ID)
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
		t.Fatalf("Failed to decode response: %v", err)
	}

	if len(response) != 2 {
		t.Errorf("Expected 2 products, got %d", len(response))
	}
}

func TestProxyToProductService(t *testing.T) {
	server := setupTestServer(t)

	expectedResponse := `{"data":"test"}`

	mockClient := &MockHTTPClient{
		DoFunc: func(req *http.Request) (*http.Response, error) {
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
		t.Fatalf("Failed to decode error response: %v", err)
	}

	if errorResp.Error != "Test Error" {
		t.Errorf("Expected error 'Test Error', got %s", errorResp.Error)
	}
}
