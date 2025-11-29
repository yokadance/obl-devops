package main

import (
	"embed"
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
	productServiceURL := getEnv("PRODUCT_SERVICE_URL", "http://localhost:8001")
	inventoryServiceURL := getEnv("INVENTORY_SERVICE_URL", "http://localhost:8002")
	redisURL := getEnv("REDIS_URL", "localhost:6379")

	redisClient := redis.NewClient(&redis.Options{
		Addr:         redisURL,
		DB:           0,
		DialTimeout:  10 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	ctx := redisClient.Context()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Fatal("Error connecting to Redis:", err)
	}

	httpClient := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 10,
			IdleConnTimeout:     90 * time.Second,
		},
	}

	staticFS, _ := fs.Sub(staticFiles, "static")
	server := NewServer(productServiceURL, inventoryServiceURL, redisClient, httpClient, staticFiles)

	log.Println("✅ API Gateway started successfully")

	r := setupRouter(server, staticFS)

	log.Println("🚀 API Gateway listening on :8000")
	log.Println("🌐 Frontend available at http://localhost:8000")
	if err := http.ListenAndServe(":8000", r); err != nil {
		log.Fatal(err)
	}
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func setupRouter(server *Server, staticFS fs.FS) *chi.Mux {
	r := chi.NewRouter()

	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Compress(5))

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))
	r.Get("/", server.ServeIndex)
	r.Get("/health", server.HealthCheck)

	r.Get("/api/products", server.ProxyToProductService)
	r.Get("/api/products/{id}", server.GetProductWithInventory)
	r.Post("/api/products", server.ProxyToProductService)
	r.Put("/api/products/{id}", server.ProxyToProductService)
	r.Delete("/api/products/{id}", server.ProxyToProductService)

	r.Get("/api/inventory", server.ProxyToInventoryService)
	r.Get("/api/inventory/{id}", server.ProxyToInventoryService)
	r.Get("/api/inventory/product/{product_id}", server.ProxyToInventoryService)
	r.Post("/api/inventory", server.ProxyToInventoryService)
	r.Put("/api/inventory/{id}", server.ProxyToInventoryService)
	r.Delete("/api/inventory/{id}", server.ProxyToInventoryService)

	r.Get("/api/products-full", server.GetAllProductsWithInventory)

	return r
}

