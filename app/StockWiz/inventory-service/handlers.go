package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-redis/redis/v8"
)

// InventoryService encapsula las dependencias del servicio
type InventoryService struct {
	DB          *sql.DB
	RedisClient *redis.Client
	Ctx         context.Context
}

// NewInventoryService crea una nueva instancia del servicio
func NewInventoryService(db *sql.DB, redisClient *redis.Client) *InventoryService {
	return &InventoryService{
		DB:          db,
		RedisClient: redisClient,
		Ctx:         context.Background(),
	}
}

func (s *InventoryService) HealthCheck(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"status":  "healthy",
		"service": "inventory-service",
	}
	json.NewEncoder(w).Encode(response)
}

func (s *InventoryService) GetInventoryList(w http.ResponseWriter, r *http.Request) {
	cacheKey := "inventory:all"

	// Intentar obtener del cache
	cached, err := s.RedisClient.Get(s.Ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	rows, err := s.DB.Query("SELECT id, product_id, quantity, warehouse, last_updated FROM inventory ORDER BY id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var inventories []Inventory
	for rows.Next() {
		var inv Inventory
		if err := rows.Scan(&inv.ID, &inv.ProductID, &inv.Quantity, &inv.Warehouse, &inv.LastUpdated); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		inventories = append(inventories, inv)
	}

	response, _ := json.Marshal(inventories)

	// Guardar en cache por 5 minutos
	s.RedisClient.Set(s.Ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func (s *InventoryService) GetInventory(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	cacheKey := fmt.Sprintf("inventory:%d", id)

	// Intentar obtener del cache
	cached, err := s.RedisClient.Get(s.Ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	var inv Inventory
	err = s.DB.QueryRow(
		"SELECT id, product_id, quantity, warehouse, last_updated FROM inventory WHERE id = $1",
		id,
	).Scan(&inv.ID, &inv.ProductID, &inv.Quantity, &inv.Warehouse, &inv.LastUpdated)

	if err == sql.ErrNoRows {
		http.Error(w, "Inventory not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response, _ := json.Marshal(inv)

	// Guardar en cache por 5 minutos
	s.RedisClient.Set(s.Ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func (s *InventoryService) GetInventoryByProduct(w http.ResponseWriter, r *http.Request) {
	productIDStr := chi.URLParam(r, "product_id")
	productID, err := strconv.Atoi(productIDStr)
	if err != nil {
		http.Error(w, "Invalid product ID", http.StatusBadRequest)
		return
	}

	cacheKey := fmt.Sprintf("inventory:product:%d", productID)

	// Intentar obtener del cache
	cached, err := s.RedisClient.Get(s.Ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	var inv Inventory
	err = s.DB.QueryRow(
		"SELECT id, product_id, quantity, warehouse, last_updated FROM inventory WHERE product_id = $1",
		productID,
	).Scan(&inv.ID, &inv.ProductID, &inv.Quantity, &inv.Warehouse, &inv.LastUpdated)

	if err == sql.ErrNoRows {
		http.Error(w, "Inventory not found for this product", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response, _ := json.Marshal(inv)

	// Guardar en cache por 5 minutos
	s.RedisClient.Set(s.Ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func (s *InventoryService) CreateInventory(w http.ResponseWriter, r *http.Request) {
	var inv InventoryCreate
	if err := json.NewDecoder(r.Body).Decode(&inv); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var newInv Inventory
	err := s.DB.QueryRow(
		"INSERT INTO inventory (product_id, quantity, warehouse) VALUES ($1, $2, $3) RETURNING id, product_id, quantity, warehouse, last_updated",
		inv.ProductID, inv.Quantity, inv.Warehouse,
	).Scan(&newInv.ID, &newInv.ProductID, &newInv.Quantity, &newInv.Warehouse, &newInv.LastUpdated)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Invalidar todos los caches relacionados
	s.invalidateInventoryCaches(inv.ProductID, newInv.ID)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(newInv)
}

func (s *InventoryService) UpdateInventory(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	var update InventoryUpdate
	if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Obtener product_id actual
	var productID int
	err = s.DB.QueryRow("SELECT product_id FROM inventory WHERE id = $1", id).Scan(&productID)
	if err == sql.ErrNoRows {
		http.Error(w, "Inventory not found", http.StatusNotFound)
		return
	}

	query := "UPDATE inventory SET last_updated = CURRENT_TIMESTAMP"
	args := []interface{}{}
	argPos := 1

	if update.Quantity != nil {
		query += fmt.Sprintf(", quantity = $%d", argPos)
		args = append(args, *update.Quantity)
		argPos++
	}
	if update.Warehouse != nil {
		query += fmt.Sprintf(", warehouse = $%d", argPos)
		args = append(args, *update.Warehouse)
		argPos++
	}

	query += fmt.Sprintf(" WHERE id = $%d RETURNING id, product_id, quantity, warehouse, last_updated", argPos)
	args = append(args, id)

	var inv Inventory
	err = s.DB.QueryRow(query, args...).Scan(&inv.ID, &inv.ProductID, &inv.Quantity, &inv.Warehouse, &inv.LastUpdated)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Invalidar caches
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("inventory:%d", id))
	s.RedisClient.Del(s.Ctx, "inventory:all")
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("inventory:product:%d", productID))

	json.NewEncoder(w).Encode(inv)
}

func (s *InventoryService) DeleteInventory(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	result, err := s.DB.Exec("DELETE FROM inventory WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Inventory not found", http.StatusNotFound)
		return
	}

	// Invalidar caches
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("inventory:%d", id))
	s.RedisClient.Del(s.Ctx, "inventory:all")

	w.WriteHeader(http.StatusNoContent)
}

// Función helper para invalidar todos los caches relacionados
func (s *InventoryService) invalidateInventoryCaches(productID, inventoryID int) {
	// Caches de inventory service
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("inventory:%d", inventoryID))
	s.RedisClient.Del(s.Ctx, "inventory:all")
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("inventory:product:%d", productID))

	// Caches del API Gateway (productos con inventario)
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("gateway:product_full:%d", productID))
	s.RedisClient.Del(s.Ctx, "gateway:products_full:all")

	// Caches del product service
	s.RedisClient.Del(s.Ctx, fmt.Sprintf("product:%d", productID))
	s.RedisClient.Del(s.Ctx, "products:all")
}
