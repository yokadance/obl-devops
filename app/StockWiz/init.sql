-- Conectar a la base de datos correcta
\c microservices_db;

-- Tabla de productos
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de inventario
CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL UNIQUE,
    quantity INTEGER NOT NULL DEFAULT 0,
    warehouse VARCHAR(100),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Índices para optimizar consultas
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_inventory_product_id ON inventory(product_id);

-- Datos de ejemplo
INSERT INTO products (name, description, price, category) VALUES
    ('Laptop Dell XPS 13', 'Ultrabook potente y ligera', 1299.99, 'Electronics'),
    ('Mouse Logitech MX Master', 'Mouse ergonómico inalámbrico', 99.99, 'Electronics'),
    ('Teclado Mecánico', 'Teclado mecánico RGB', 149.99, 'Electronics'),
    ('Monitor 4K', 'Monitor 27 pulgadas 4K', 499.99, 'Electronics'),
    ('Webcam HD', 'Cámara web Full HD', 79.99, 'Electronics');

INSERT INTO inventory (product_id, quantity, warehouse) VALUES
    (1, 50, 'Warehouse A'),
    (2, 150, 'Warehouse A'),
    (3, 75, 'Warehouse B'),
    (4, 30, 'Warehouse A'),
    (5, 100, 'Warehouse B');