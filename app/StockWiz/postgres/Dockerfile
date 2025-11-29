FROM postgres:15-alpine

# Copiar el script de inicialización
COPY ../init.sql /docker-entrypoint-initdb.d/

# Variables de entorno - deben ser provistas en runtime
# No usar valores por defecto para passwords (seguridad)
ENV POSTGRES_USER=${POSTGRES_USER:-admin}
ENV POSTGRES_DB=${POSTGRES_DB:-microservices_db}

# POSTGRES_PASSWORD debe ser provista obligatoriamente en runtime

# Exponer puerto
EXPOSE 5432