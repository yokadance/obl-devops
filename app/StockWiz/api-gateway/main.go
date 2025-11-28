package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-redis/redis/v8"
)

//go:embed static/*
var staticFiles embed.FS

var (
	productServiceURL   string
	inventoryServiceURL string
	redisClient         *redis.Client
	ctx                 = context.Background()
	httpClient          *http.Client
)

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

type ProductWithInventory struct {
	ID          int     `json:"id"`
	Name        string  `json:"name"`
	Description *string `json:"description"`
	Price       float64 `json:"price"`
	Category    *string `json:"category"`
	Inventory   *struct {
		Quantity  int    `json:"quantity"`
		Warehouse string `json:"warehouse"`
	} `json:"inventory,omitempty"`
}

func main() {
	// Configuración de servicios
	productServiceURL = os.Getenv("PRODUCT_SERVICE_URL")
	if productServiceURL == "" {
		productServiceURL = "http://localhost:8001"
	}

	inventoryServiceURL = os.Getenv("INVENTORY_SERVICE_URL")
	if inventoryServiceURL == "" {
		inventoryServiceURL = "http://localhost:8002"
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

	// Configurar HTTP client con timeout y pool
	httpClient = &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	log.Println("✅ API Gateway started successfully")

	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Compress(5))

	// CORS
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	// Servir archivos estáticos (Frontend)
	staticFS, _ := fs.Sub(staticFiles, "static")
	r.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))

	// Ruta principal - servir index.html
	r.Get("/", serveIndex)

	// API Routes
	r.Get("/health", healthCheck)

	// Product routes (proxy)
	r.Get("/api/products", proxyToProductService)
	r.Get("/api/products/{id}", getProductWithInventory)
	r.Post("/api/products", proxyToProductService)
	r.Put("/api/products/{id}", proxyToProductService)
	r.Delete("/api/products/{id}", proxyToProductService)

	// Inventory routes (proxy)
	r.Get("/api/inventory", proxyToInventoryService)
	r.Get("/api/inventory/{id}", proxyToInventoryService)
	r.Get("/api/inventory/product/{product_id}", proxyToInventoryService)
	r.Post("/api/inventory", proxyToInventoryService)
	r.Put("/api/inventory/{id}", proxyToInventoryService)
	r.Delete("/api/inventory/{id}", proxyToInventoryService)

	// Endpoint agregado especial
	r.Get("/api/products-full", getAllProductsWithInventory)

	log.Println("🚀 API Gateway listening on :8000")
	log.Println("🌐 Frontend available at http://localhost:8000")
	if err := http.ListenAndServe(":8000", r); err != nil {
		log.Fatal(err)
	}
}

func serveIndex(w http.ResponseWriter, r *http.Request) {
	data, err := staticFiles.ReadFile("static/index.html")
	if err != nil {
		http.Error(w, "Could not load page", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Verificar salud de servicios downstream
	productHealth := checkServiceHealth(productServiceURL + "/health")
	inventoryHealth := checkServiceHealth(inventoryServiceURL + "/health")

	response := map[string]interface{}{
		"status":  "healthy",
		"service": "api-gateway",
		"downstream_services": map[string]string{
			"product_service":   productHealth,
			"inventory_service": inventoryHealth,
		},
	}

	json.NewEncoder(w).Encode(response)
}

func checkServiceHealth(url string) string {
	resp, err := httpClient.Get(url)
	if err != nil {
		return "unhealthy"
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return "healthy"
	}
	return "unhealthy"
}

func proxyToProductService(w http.ResponseWriter, r *http.Request) {
	proxyRequest(w, r, productServiceURL)
}

func proxyToInventoryService(w http.ResponseWriter, r *http.Request) {
	proxyRequest(w, r, inventoryServiceURL)
}

func proxyRequest(w http.ResponseWriter, r *http.Request, targetURL string) {
	// Construir URL del servicio destino - remover el prefijo /api
	path := r.URL.Path
	if len(path) >= 4 && path[:4] == "/api" {
		path = path[4:]
	}

	url := targetURL + path
	if r.URL.RawQuery != "" {
		url += "?" + r.URL.RawQuery
	}

	// Crear request
	proxyReq, err := http.NewRequest(r.Method, url, r.Body)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "Error creating proxy request", err.Error())
		return
	}

	// Copiar headers
	for key, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(key, value)
		}
	}

	// Ejecutar request
	resp, err := httpClient.Do(proxyReq)
	if err != nil {
		sendError(w, http.StatusBadGateway, "Error connecting to service", err.Error())
		return
	}
	defer resp.Body.Close()

	// Copiar headers de respuesta
	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}

	// Copiar status code
	w.WriteHeader(resp.StatusCode)

	// Copiar body
	io.Copy(w, resp.Body)
}

func getProductWithInventory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	productID := chi.URLParam(r, "id")
	cacheKey := fmt.Sprintf("gateway:product_full:%s", productID)

	// Intentar obtener del cache
	cached, err := redisClient.Get(ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	// Obtener producto
	productResp, err := httpClient.Get(fmt.Sprintf("%s/products/%s", productServiceURL, productID))
	if err != nil {
		sendError(w, http.StatusBadGateway, "Error connecting to product service", err.Error())
		return
	}
	defer productResp.Body.Close()

	if productResp.StatusCode != http.StatusOK {
		w.WriteHeader(productResp.StatusCode)
		io.Copy(w, productResp.Body)
		return
	}

	var product ProductWithInventory
	if err := json.NewDecoder(productResp.Body).Decode(&product); err != nil {
		sendError(w, http.StatusInternalServerError, "Error decoding product", err.Error())
		return
	}

	// Obtener inventario (no fallar si no existe)
	inventoryResp, err := httpClient.Get(fmt.Sprintf("%s/inventory/product/%s", inventoryServiceURL, productID))
	if err == nil && inventoryResp.StatusCode == http.StatusOK {
		defer inventoryResp.Body.Close()

		var inventory struct {
			Quantity  int    `json:"quantity"`
			Warehouse string `json:"warehouse"`
		}

		if err := json.NewDecoder(inventoryResp.Body).Decode(&inventory); err == nil {
			product.Inventory = &struct {
				Quantity  int    `json:"quantity"`
				Warehouse string `json:"warehouse"`
			}{
				Quantity:  inventory.Quantity,
				Warehouse: inventory.Warehouse,
			}
		}
	}

	response, _ := json.Marshal(product)

	// Guardar en cache por 3 minutos
	redisClient.Set(ctx, cacheKey, response, 3*time.Minute)

	w.Write(response)
}

func getAllProductsWithInventory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	cacheKey := "gateway:products_full:all"

	// Verificar si se solicita forzar refresh (parámetro force_refresh)
	forceRefresh := r.URL.Query().Get("force_refresh") == "true"

	// Intentar obtener del cache solo si no se fuerza refresh
	if !forceRefresh {
		cached, err := redisClient.Get(ctx, cacheKey).Result()
		if err == nil {
			w.Write([]byte(cached))
			return
		}
	}

	// Obtener todos los productos
	productsResp, err := httpClient.Get(fmt.Sprintf("%s/products", productServiceURL))
	if err != nil {
		sendError(w, http.StatusBadGateway, "Error connecting to product service", err.Error())
		return
	}
	defer productsResp.Body.Close()

	if productsResp.StatusCode != http.StatusOK {
		w.WriteHeader(productsResp.StatusCode)
		io.Copy(w, productsResp.Body)
		return
	}

	var products []ProductWithInventory
	if err := json.NewDecoder(productsResp.Body).Decode(&products); err != nil {
		sendError(w, http.StatusInternalServerError, "Error decoding products", err.Error())
		return
	}

	// Obtener inventario para cada producto
	for i := range products {
		inventoryResp, err := httpClient.Get(fmt.Sprintf("%s/inventory/product/%d", inventoryServiceURL, products[i].ID))
		if err == nil && inventoryResp.StatusCode == http.StatusOK {
			var inventory struct {
				Quantity  int    `json:"quantity"`
				Warehouse string `json:"warehouse"`
			}

			if err := json.NewDecoder(inventoryResp.Body).Decode(&inventory); err == nil {
				products[i].Inventory = &struct {
					Quantity  int    `json:"quantity"`
					Warehouse string `json:"warehouse"`
				}{
					Quantity:  inventory.Quantity,
					Warehouse: inventory.Warehouse,
				}
			}
			inventoryResp.Body.Close()
		}
	}

	response, _ := json.Marshal(products)

	// Guardar en cache por 3 minutos
	redisClient.Set(ctx, cacheKey, response, 3*time.Minute)

	w.Write(response)
}

func sendError(w http.ResponseWriter, status int, message, detail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error:   message,
		Message: detail,
	})
}
