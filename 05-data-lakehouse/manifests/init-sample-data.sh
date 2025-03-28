#!/bin/bash

# Esperar a que Trino esté disponible
echo "Esperando a que Trino esté listo..."
until curl -s http://trino-coordinator:8080/v1/info > /dev/null; do
  sleep 5
done
echo "Trino está listo."

# Credenciales para Trino (básicas)
TRINO_USER="admin"
TRINO_PASSWORD="admin"
AUTH_HEADER="Authorization: Basic $(echo -n "$TRINO_USER:$TRINO_PASSWORD" | base64)"

# Crear bases de datos y tablas
echo "Creando bases de datos y tablas en Iceberg..."

# Crear base de datos
curl -X POST http://trino-coordinator:8080/v1/statement \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"query": "CREATE SCHEMA IF NOT EXISTS iceberg.sales"}'

# Crear tabla de productos
curl -X POST http://trino-coordinator:8080/v1/statement \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"query": "CREATE TABLE IF NOT EXISTS iceberg.sales.products (
    product_id INTEGER,
    name VARCHAR,
    category VARCHAR,
    price DECIMAL(10, 2),
    created_at TIMESTAMP
  ) WITH (
    format = '\''PARQUET'\'',
    partitioning = ARRAY['\''category'\'']
  )"}'

# Crear tabla de transacciones
curl -X POST http://trino-coordinator:8080/v1/statement \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"query": "CREATE TABLE IF NOT EXISTS iceberg.sales.transactions (
    transaction_id INTEGER,
    product_id INTEGER,
    customer_id INTEGER,
    quantity INTEGER,
    total_amount DECIMAL(10, 2),
    transaction_date TIMESTAMP
  ) WITH (
    format = '\''PARQUET'\'',
    partitioning = ARRAY['\''date_trunc('\''month'\'', transaction_date)'\'']
  )"}'

# Insertar datos de muestra en productos
echo "Insertando datos de muestra en la tabla de productos..."
curl -X POST http://trino-coordinator:8080/v1/statement \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"query": "INSERT INTO iceberg.sales.products VALUES
    (1, '\''Laptop Pro'\'', '\''Electrónicos'\'', 1299.99, TIMESTAMP '\''2023-01-15 10:00:00'\''::TIMESTAMP),
    (2, '\''Smartphone X'\'', '\''Electrónicos'\'', 899.99, TIMESTAMP '\''2023-01-16 11:30:00'\''::TIMESTAMP),
    (3, '\''Auriculares Wireless'\'', '\''Accesorios'\'', 149.99, TIMESTAMP '\''2023-01-17 09:15:00'\''::TIMESTAMP),
    (4, '\''Monitor 4K'\'', '\''Electrónicos'\'', 349.99, TIMESTAMP '\''2023-01-18 14:20:00'\''::TIMESTAMP),
    (5, '\''Teclado Mecánico'\'', '\''Accesorios'\'', 89.99, TIMESTAMP '\''2023-01-19 16:45:00'\''::TIMESTAMP)"}'

# Insertar datos de muestra en transacciones
echo "Insertando datos de muestra en la tabla de transacciones..."
curl -X POST http://trino-coordinator:8080/v1/statement \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"query": "INSERT INTO iceberg.sales.transactions VALUES
    (101, 1, 1001, 1, 1299.99, TIMESTAMP '\''2023-02-01 10:30:00'\''::TIMESTAMP),
    (102, 2, 1002, 1, 899.99, TIMESTAMP '\''2023-02-02 11:45:00'\''::TIMESTAMP),
    (103, 3, 1001, 2, 299.98, TIMESTAMP '\''2023-02-03 09:20:00'\''::TIMESTAMP),
    (104, 4, 1003, 1, 349.99, TIMESTAMP '\''2023-03-05 14:10:00'\''::TIMESTAMP),
    (105, 5, 1002, 3, 269.97, TIMESTAMP '\''2023-03-06 16:30:00'\''::TIMESTAMP),
    (106, 1, 1004, 1, 1299.99, TIMESTAMP '\''2023-03-10 13:25:00'\''::TIMESTAMP),
    (107, 2, 1005, 2, 1799.98, TIMESTAMP '\''2023-04-12 15:40:00'\''::TIMESTAMP),
    (108, 3, 1003, 1, 149.99, TIMESTAMP '\''2023-04-15 10:15:00'\''::TIMESTAMP),
    (109, 4, 1004, 2, 699.98, TIMESTAMP '\''2023-04-18 12:50:00'\''::TIMESTAMP),
    (110, 5, 1005, 1, 89.99, TIMESTAMP '\''2023-04-20 17:05:00'\''::TIMESTAMP)"}'

echo "Datos de muestra inicializados correctamente." 