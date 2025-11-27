# Multi-stage build para optimizar tamaño
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Instalar dependencias necesarias
RUN apk add --no-cache git ca-certificates

# Copiar go.mod y go.sum
COPY go.mod go.sum ./

# Descargar dependencias
RUN go mod download

# Copiar código fuente y archivos estáticos
COPY main.go .
COPY static ./static

# Compilar aplicación con optimizaciones
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o api-gateway .

# Etapa final - imagen mínima
FROM alpine:3.18

WORKDIR /app

# Instalar certificados CA para HTTPS
RUN apk --no-cache add ca-certificates

# Copiar binario compilado
COPY --from=builder /app/api-gateway .

# Usuario no root para seguridad
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["./api-gateway"]