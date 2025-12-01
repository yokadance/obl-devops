package main

// ErrorResponse representa un error en formato JSON
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// ProductWithInventory representa un producto con su inventario
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
