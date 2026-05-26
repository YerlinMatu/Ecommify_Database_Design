-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Tabla Customers
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zip_code VARCHAR(10) NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Índice espacial para búsquedas rápidas de ubicación
CREATE INDEX idx_customers_location ON customers USING GIST (location);

-- 2. Tabla Sellers
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    zip_code VARCHAR(10) NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL
);
CREATE INDEX idx_sellers_location ON sellers USING GIST (location);

-- 3. Tabla Orders (Particionada por rango de fecha)
CREATE TABLE orders (
    order_id UUID DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('created', 'approved', 'shipped', 'delivered', 'canceled')),
    created_at TIMESTAMPTZ NOT NULL,
    delivery_window TSTZRANGE NOT NULL,
    -- En tablas particionadas, la clave de partición debe ser parte de la PK
    PRIMARY KEY (order_id, created_at),
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) PARTITION BY RANGE (created_at);

-- Creación de particiones mensuales (Ejemplo para finales de 2017 / inicios 2018 de Olist)
CREATE TABLE orders_2017_12 PARTITION OF orders FOR VALUES FROM ('2017-12-01') TO ('2018-01-01');
CREATE TABLE orders_2018_01 PARTITION OF orders FOR VALUES FROM ('2018-01-01') TO ('2018-02-01');

-- 4. Tabla Order Items
CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    order_created_at TIMESTAMPTZ NOT NULL, -- Necesario para la FK hacia la tabla particionada
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    freight_value NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    CONSTRAINT fk_order FOREIGN KEY (order_id, order_created_at) REFERENCES orders(order_id, created_at),
    CONSTRAINT fk_seller FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

-- 5. Tabla Payments
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    order_created_at TIMESTAMPTZ NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_value NUMERIC(10,2) NOT NULL CHECK (payment_value > 0),
    gateway_metadata JSONB,
    CONSTRAINT fk_order_payment FOREIGN KEY (order_id, order_created_at) REFERENCES orders(order_id, created_at)
);
-- Índice GIN para búsquedas eficientes dentro del JSONB
CREATE INDEX idx_payments_metadata ON payments USING GIN (gateway_metadata);

-- 6. Tabla Inventory
CREATE TABLE inventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR(50) NOT NULL,
    warehouse_id UUID NOT NULL,
    available_qty INTEGER NOT NULL CHECK (available_qty >= 0)
);