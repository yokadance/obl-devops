package main

import "time"

// Inventory representa un registro de inventario
type Inventory struct {
	ID          int       `json:"id"`
	ProductID   int       `json:"product_id"`
	Quantity    int       `json:"quantity"`
	Warehouse   string    `json:"warehouse"`
	LastUpdated time.Time `json:"last_updated"`
}

// InventoryUpdate representa una actualización parcial de inventario
type InventoryUpdate struct {
	Quantity  *int    `json:"quantity,omitempty"`
	Warehouse *string `json:"warehouse,omitempty"`
}

// InventoryCreate representa la creación de un nuevo inventario
type InventoryCreate struct {
	ProductID int    `json:"product_id"`
	Quantity  int    `json:"quantity"`
	Warehouse string `json:"warehouse"`
}
