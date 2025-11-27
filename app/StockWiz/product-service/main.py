from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, List
import asyncpg
import redis.asyncio as redis
import json
import os
from contextlib import asynccontextmanager

# Modelos Pydantic
class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    price: float = Field(..., gt=0)
    category: Optional[str] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    price: Optional[float] = Field(None, gt=0)
    category: Optional[str] = None

class Product(BaseModel):
    id: int
    name: str
    description: Optional[str]
    price: float
    category: Optional[str]

# Variables globales
db_pool = None
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool, redis_client
    # Startup
    database_url = os.getenv("DATABASE_URL", "postgresql://admin:admin123@localhost:5432/microservices_db")
    redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    db_pool = await asyncpg.create_pool(database_url, min_size=2, max_size=10)
    redis_client = await redis.from_url(redis_url, encoding="utf-8", decode_responses=True)
    
    print("✅ Product Service started successfully")
    yield
    
    # Shutdown
    await db_pool.close()
    await redis_client.close()
    print("🔌 Product Service shut down")

app = FastAPI(title="Product Service", version="1.0.0", lifespan=lifespan)

# Dependency para obtener conexión a BD
async def get_db():
    async with db_pool.acquire() as connection:
        yield connection

# Health check
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "product-service"}

# Listar todos los productos
@app.get("/products", response_model=List[Product])
async def get_products(
    category: Optional[str] = None,
    db: asyncpg.Connection = Depends(get_db)
):
    cache_key = f"products:all:{category}" if category else "products:all"
    
    # Intentar obtener del cache
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Consultar BD
    if category:
        query = "SELECT * FROM products WHERE category = $1 ORDER BY id"
        rows = await db.fetch(query, category)
    else:
        query = "SELECT * FROM products ORDER BY id"
        rows = await db.fetch(query)
    
    products = [dict(row) for row in rows]
    
    # Guardar en cache por 5 minutos
    await redis_client.setex(cache_key, 300, json.dumps(products, default=str))
    
    return products

# Obtener producto por ID
@app.get("/products/{product_id}", response_model=Product)
async def get_product(product_id: int, db: asyncpg.Connection = Depends(get_db)):
    cache_key = f"product:{product_id}"
    
    # Intentar obtener del cache
    cached = await redis_client.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Consultar BD
    query = "SELECT * FROM products WHERE id = $1"
    row = await db.fetchrow(query, product_id)
    
    if not row:
        raise HTTPException(status_code=404, detail="Product not found")
    
    product = dict(row)
    
    # Guardar en cache por 5 minutos
    await redis_client.setex(cache_key, 300, json.dumps(product, default=str))
    
    return product

# Crear producto
@app.post("/products", response_model=Product, status_code=201)
async def create_product(product: ProductCreate, db: asyncpg.Connection = Depends(get_db)):
    query = """
        INSERT INTO products (name, description, price, category)
        VALUES ($1, $2, $3, $4)
        RETURNING *
    """
    row = await db.fetchrow(
        query, product.name, product.description, product.price, product.category
    )
    
    new_product = dict(row)
    
    # Invalidar cache de listados (product service y gateway)
    await redis_client.delete("products:all")
    await redis_client.delete("gateway:products_full:all")
    if product.category:
        await redis_client.delete(f"products:all:{product.category}")
    
    return new_product

# Actualizar producto
@app.put("/products/{product_id}", response_model=Product)
async def update_product(
    product_id: int,
    product: ProductUpdate,
    db: asyncpg.Connection = Depends(get_db)
):
    # Verificar que existe
    exists = await db.fetchrow("SELECT id, category FROM products WHERE id = $1", product_id)
    if not exists:
        raise HTTPException(status_code=404, detail="Product not found")
    
    old_category = exists['category']
    
    # Construir query dinámicamente
    updates = []
    values = []
    counter = 1
    
    if product.name is not None:
        updates.append(f"name = ${counter}")
        values.append(product.name)
        counter += 1
    if product.description is not None:
        updates.append(f"description = ${counter}")
        values.append(product.description)
        counter += 1
    if product.price is not None:
        updates.append(f"price = ${counter}")
        values.append(product.price)
        counter += 1
    if product.category is not None:
        updates.append(f"category = ${counter}")
        values.append(product.category)
        counter += 1
    
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    updates.append(f"updated_at = CURRENT_TIMESTAMP")
    values.append(product_id)
    
    query = f"""
        UPDATE products
        SET {', '.join(updates)}
        WHERE id = ${counter}
        RETURNING *
    """
    
    row = await db.fetchrow(query, *values)
    updated_product = dict(row)
    
    # Invalidar caches
    await redis_client.delete(f"product:{product_id}")
    await redis_client.delete("products:all")
    await redis_client.delete(f"products:all:{old_category}")
    if product.category:
        await redis_client.delete(f"products:all:{product.category}")
    
    return updated_product

# Eliminar producto
@app.delete("/products/{product_id}", status_code=204)
async def delete_product(product_id: int, db: asyncpg.Connection = Depends(get_db)):
    result = await db.execute("DELETE FROM products WHERE id = $1", product_id)
    
    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail="Product not found")
    
    # Invalidar caches
    await redis_client.delete(f"product:{product_id}")
    await redis_client.delete("products:all")
    
    return None

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)