FROM postgres:15-alpine

# Copiar el script de inicialización
COPY init.sql /docker-entrypoint-initdb.d/

# Variables de entorno por defecto (pueden ser sobrescritas)
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=admin123
ENV POSTGRES_DB=microservices_db

# Exponer puerto
EXPOSE 5432