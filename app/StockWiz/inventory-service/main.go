package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-redis/redis/v8"
	_ "github.com/lib/pq"
)

var (
	db          *sql.DB
	redisClient *redis.Client
	ctx         = context.Background()
)

type Inventory struct {
	ID          int       `json:"id"`
	ProductID   int       `json:"product_id"`
	Quantity    int       `json:"quantity"`
	Warehouse   string    `json:"warehouse"`
	LastUpdated time.Time `json:"last_updated"`
}

type InventoryUpdate struct {
	Quantity  *int    `json:"quantity,omitempty"`
	Warehouse *string `json:"warehouse,omitempty"`
}

type InventoryCreate struct {
	ProductID int    `json:"product_id"`
	Quantity  int    `json:"quantity"`
	Warehouse string `json:"warehouse"`
}

func main() {
	// Conectar a PostgreSQL
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://admin:admin123@localhost:5432/microservices_db?sslmode=disable"
	}

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal("Error connecting to database:", err)
	}
	defer db.Close()

	// Configurar pool de conexiones
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Verificar conexión
	if err := db.Ping(); err != nil {
		log.Fatal("Error pinging database:", err)
	}

	// Conectar a Redis
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "localhost:6379"
	}

	redisClient = redis.NewClient(&redis.Options{
		Addr:         redisURL,
		DB:           0,
		DialTimeout:  10 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	// Verificar conexión a Redis
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Fatal("Error connecting to Redis:", err)
	}

	log.Println("✅ Inventory Service started successfully")

	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(middleware.SetHeader("Content-Type", "application/json"))

	// Routes
	r.Get("/health", healthCheck)
	r.Get("/inventory", getInventoryList)
	r.Get("/inventory/{id}", getInventory)
	r.Get("/inventory/product/{product_id}", getInventoryByProduct)
	r.Post("/inventory", createInventory)
	r.Put("/inventory/{id}", updateInventory)
	r.Delete("/inventory/{id}", deleteInventory)

	log.Println("🚀 Server listening on :8002")
	if err := http.ListenAndServe(":8002", r); err != nil {
		log.Fatal(err)
	}
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"status":  "healthy",
		"service": "inventory-service",
	}
	json.NewEncoder(w).Encode(response)
}

func getInventoryList(w http.ResponseWriter, r *http.Request) {
	cacheKey := "inventory:all"

	// Intentar obtener del cache
	cached, err := redisClient.Get(ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	rows, err := db.Query("SELECT id, product_id, quantity, warehouse, last_updated FROM inventory ORDER BY id")
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
	redisClient.Set(ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func getInventory(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	cacheKey := fmt.Sprintf("inventory:%d", id)

	// Intentar obtener del cache
	cached, err := redisClient.Get(ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	var inv Inventory
	err = db.QueryRow(
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
	redisClient.Set(ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func getInventoryByProduct(w http.ResponseWriter, r *http.Request) {
	productIDStr := chi.URLParam(r, "product_id")
	productID, err := strconv.Atoi(productIDStr)
	if err != nil {
		http.Error(w, "Invalid product ID", http.StatusBadRequest)
		return
	}

	cacheKey := fmt.Sprintf("inventory:product:%d", productID)

	// Intentar obtener del cache
	cached, err := redisClient.Get(ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	var inv Inventory
	err = db.QueryRow(
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
	redisClient.Set(ctx, cacheKey, response, 5*time.Minute)

	w.Write(response)
}

func createInventory(w http.ResponseWriter, r *http.Request) {
	var inv InventoryCreate
	if err := json.NewDecoder(r.Body).Decode(&inv); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var newInv Inventory
	err := db.QueryRow(
		"INSERT INTO inventory (product_id, quantity, warehouse) VALUES ($1, $2, $3) RETURNING id, product_id, quantity, warehouse, last_updated",
		inv.ProductID, inv.Quantity, inv.Warehouse,
	).Scan(&newInv.ID, &newInv.ProductID, &newInv.Quantity, &newInv.Warehouse, &newInv.LastUpdated)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Invalidar todos los caches relacionados
	invalidateInventoryCaches(inv.ProductID, newInv.ID)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(newInv)
}

func updateInventory(w http.ResponseWriter, r *http.Request) {
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
	err = db.QueryRow("SELECT product_id FROM inventory WHERE id = $1", id).Scan(&productID)
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
	err = db.QueryRow(query, args...).Scan(&inv.ID, &inv.ProductID, &inv.Quantity, &inv.Warehouse, &inv.LastUpdated)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Invalidar caches
	redisClient.Del(ctx, fmt.Sprintf("inventory:%d", id))
	redisClient.Del(ctx, "inventory:all")
	redisClient.Del(ctx, fmt.Sprintf("inventory:product:%d", productID))

	json.NewEncoder(w).Encode(inv)
}

func deleteInventory(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		http.Error(w, "Invalid ID", http.StatusBadRequest)
		return
	}

	result, err := db.Exec("DELETE FROM inventory WHERE id = $1", id)
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
	redisClient.Del(ctx, fmt.Sprintf("inventory:%d", id))
	redisClient.Del(ctx, "inventory:all")

	w.WriteHeader(http.StatusNoContent)
}

// Función helper para invalidar todos los caches relacionados
func invalidateInventoryCaches(productID, inventoryID int) {
	// Caches de inventory service
	redisClient.Del(ctx, fmt.Sprintf("inventory:%d", inventoryID))
	redisClient.Del(ctx, "inventory:all")
	redisClient.Del(ctx, fmt.Sprintf("inventory:product:%d", productID))

	// Caches del API Gateway (productos con inventario)
	redisClient.Del(ctx, fmt.Sprintf("gateway:product_full:%d", productID))
	redisClient.Del(ctx, "gateway:products_full:all")

	// Caches del product service
	redisClient.Del(ctx, fmt.Sprintf("product:%d", productID))
	redisClient.Del(ctx, "products:all")

	log.Printf("Cache invalidated for product_id=%d, inventory_id=%d", productID, inventoryID)
}
