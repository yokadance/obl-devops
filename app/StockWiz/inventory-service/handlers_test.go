package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/go-redis/redis/v8"
)

func TestHealthCheck(t *testing.T) {
	// Setup
	db, _, _ := sqlmock.New()
	defer db.Close()

	redisClient := redis.NewClient(&redis.Options{Addr: "localhost:63799", DB: 15})
	service := NewInventoryService(db, redisClient)

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	// Execute
	service.HealthCheck(w, req)

	// Assert
	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]string
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("Expected status 'healthy', got %s", response["status"])
	}
	if response["service"] != "inventory-service" {
		t.Errorf("Expected service 'inventory-service', got %s", response["service"])
	}
}

func TestCreateInventory(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("Failed to create mock: %v", err)
	}
	defer db.Close()

	redisClient := redis.NewClient(&redis.Options{Addr: "localhost:63799", DB: 15})
	service := NewInventoryService(db, redisClient)

	// Prepare mock
	rows := sqlmock.NewRows([]string{"id", "product_id", "quantity", "warehouse", "last_updated"}).
		AddRow(1, 100, 50, "Warehouse A", "2025-01-01 00:00:00")

	mock.ExpectQuery("INSERT INTO inventory").
		WithArgs(100, 50, "Warehouse A").
		WillReturnRows(rows)

	// Prepare request
	createReq := InventoryCreate{
		ProductID: 100,
		Quantity:  50,
		Warehouse: "Warehouse A",
	}
	body, _ := json.Marshal(createReq)
	req := httptest.NewRequest("POST", "/inventory", bytes.NewBuffer(body))
	w := httptest.NewRecorder()

	// Execute
	service.CreateInventory(w, req)

	// Assert
	if w.Code != http.StatusCreated {
		t.Errorf("Expected status 201, got %d", w.Code)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Unfulfilled expectations: %v", err)
	}
}

func TestNewInventoryService(t *testing.T) {
	db, _, _ := sqlmock.New()
	defer db.Close()

	redisClient := redis.NewClient(&redis.Options{Addr: "localhost:63799", DB: 15})
	service := NewInventoryService(db, redisClient)

	if service == nil {
		t.Fatal("Service should not be nil")
	}
	if service.DB == nil {
		t.Error("DB should not be nil")
	}
	if service.RedisClient == nil {
		t.Error("RedisClient should not be nil")
	}
}

func TestInvalidInventoryID(t *testing.T) {
	db, _, _ := sqlmock.New()
	defer db.Close()

	redisClient := redis.NewClient(&redis.Options{Addr: "localhost:63799", DB: 15})
	service := NewInventoryService(db, redisClient)

	req := httptest.NewRequest("GET", "/inventory/invalid", nil)
	w := httptest.NewRecorder()

	// Mock chi URL params - sin chi context se debería manejar el error
	service.GetInventory(w, req)

	// Como no hay URLParam, debería fallar en la conversión
	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400 for invalid ID, got %d", w.Code)
	}
}
