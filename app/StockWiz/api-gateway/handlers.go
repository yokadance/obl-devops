package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-redis/redis/v8"
)

// HTTPClient interface para poder mockear el cliente HTTP
type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
	Get(url string) (*http.Response, error)
}

// Server encapsula las dependencias del servidor
type Server struct {
	ProductServiceURL   string
	InventoryServiceURL string
	RedisClient         *redis.Client
	HTTPClient          HTTPClient
	StaticFiles         fs.FS
	Ctx                 context.Context
}

// NewServer crea una nueva instancia del servidor
func NewServer(productURL, inventoryURL string, redisClient *redis.Client, httpClient HTTPClient, staticFiles fs.FS) *Server {
	return &Server{
		ProductServiceURL:   productURL,
		InventoryServiceURL: inventoryURL,
		RedisClient:         redisClient,
		HTTPClient:          httpClient,
		StaticFiles:         staticFiles,
		Ctx:                 context.Background(),
	}
}

func (s *Server) ServeIndex(w http.ResponseWriter, r *http.Request) {
	data, err := fs.ReadFile(s.StaticFiles, "static/index.html")
	if err != nil {
		http.Error(w, "Could not load page", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

func (s *Server) HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	productHealth := s.checkServiceHealth(s.ProductServiceURL + "/health")
	inventoryHealth := s.checkServiceHealth(s.InventoryServiceURL + "/health")

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

func (s *Server) checkServiceHealth(url string) string {
	resp, err := s.HTTPClient.Get(url)
	if err != nil {
		return "unhealthy"
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return "healthy"
	}
	return "unhealthy"
}

func (s *Server) ProxyToProductService(w http.ResponseWriter, r *http.Request) {
	s.proxyRequest(w, r, s.ProductServiceURL)
}

func (s *Server) ProxyToInventoryService(w http.ResponseWriter, r *http.Request) {
	s.proxyRequest(w, r, s.InventoryServiceURL)
}

func (s *Server) proxyRequest(w http.ResponseWriter, r *http.Request, targetURL string) {
	path := r.URL.Path
	if len(path) >= 4 && path[:4] == "/api" {
		path = path[4:]
	}

	url := targetURL + path
	if r.URL.RawQuery != "" {
		url += "?" + r.URL.RawQuery
	}

	proxyReq, err := http.NewRequest(r.Method, url, r.Body)
	if err != nil {
		s.sendError(w, http.StatusInternalServerError, "Error creating proxy request", err.Error())
		return
	}

	for key, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(key, value)
		}
	}

	resp, err := s.HTTPClient.Do(proxyReq)
	if err != nil {
		s.sendError(w, http.StatusBadGateway, "Error connecting to service", err.Error())
		return
	}
	defer resp.Body.Close()

	for key, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}

	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func (s *Server) GetProductWithInventory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	productID := chi.URLParam(r, "id")
	cacheKey := fmt.Sprintf("gateway:product_full:%s", productID)

	cached, err := s.RedisClient.Get(s.Ctx, cacheKey).Result()
	if err == nil {
		w.Write([]byte(cached))
		return
	}

	productResp, err := s.HTTPClient.Get(fmt.Sprintf("%s/products/%s", s.ProductServiceURL, productID))
	if err != nil {
		s.sendError(w, http.StatusBadGateway, "Error connecting to product service", err.Error())
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
		s.sendError(w, http.StatusInternalServerError, "Error decoding product", err.Error())
		return
	}

	inventoryResp, err := s.HTTPClient.Get(fmt.Sprintf("%s/inventory/product/%s", s.InventoryServiceURL, productID))
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
	s.RedisClient.Set(s.Ctx, cacheKey, response, 3*time.Minute)
	w.Write(response)
}

func (s *Server) GetAllProductsWithInventory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	cacheKey := "gateway:products_full:all"
	forceRefresh := r.URL.Query().Get("force_refresh") == "true"

	if !forceRefresh {
		cached, err := s.RedisClient.Get(s.Ctx, cacheKey).Result()
		if err == nil {
			w.Write([]byte(cached))
			return
		}
	}

	productsResp, err := s.HTTPClient.Get(fmt.Sprintf("%s/products", s.ProductServiceURL))
	if err != nil {
		s.sendError(w, http.StatusBadGateway, "Error connecting to product service", err.Error())
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
		s.sendError(w, http.StatusInternalServerError, "Error decoding products", err.Error())
		return
	}

	for i := range products {
		inventoryResp, err := s.HTTPClient.Get(fmt.Sprintf("%s/inventory/product/%d", s.InventoryServiceURL, products[i].ID))
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
	s.RedisClient.Set(s.Ctx, cacheKey, response, 3*time.Minute)
	w.Write(response)
}

func (s *Server) sendError(w http.ResponseWriter, status int, message, detail string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{
		Error:   message,
		Message: detail,
	})
}
