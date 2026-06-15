CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE geolocation (
    geolocation_zip_code_prefix TEXT PRIMARY KEY,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state TEXT,
    geolocation_geom geometry(Point,4326)
);

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT REFERENCES geolocation(geolocation_zip_code_prefix),
    customer_city TEXT,
    customer_state TEXT
);

CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT REFERENCES geolocation(geolocation_zip_code_prefix),
    seller_city TEXT,
    seller_state TEXT
);

CREATE TABLE product_category_name_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT REFERENCES product_category_name_translation(product_category_name),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g DOUBLE PRECISION,
    product_length_cm DOUBLE PRECISION,
    product_height_cm DOUBLE PRECISION
);

CREATE TABLE orders (
    order_id TEXT,
    customer_id TEXT REFERENCES customers(customer_id),
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP WITH TIME ZONE,
    order_approved_at TIMESTAMP WITH TIME ZONE,
    order_delivered_carrier_date TIMESTAMP WITH TIME ZONE,
    order_delivered_customer_date TIMESTAMP WITH TIME ZONE,
    order_estimated_delivery_date TIMESTAMP WITH TIME ZONE,
    -- La clave primaria debe incluir la columna de partición
    PRIMARY KEY (order_id, order_purchase_timestamp)
) PARTITION BY RANGE (order_purchase_timestamp);

-- Crear particiones (ejemplo para 2017 y partición por defecto)
CREATE TABLE orders_2017 PARTITION OF orders
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');

CREATE TABLE orders_default PARTITION OF orders DEFAULT;

CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id TEXT,
    order_purchase_timestamp TIMESTAMP WITH TIME ZONE,
    product_id TEXT REFERENCES products(product_id),
    seller_id TEXT REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP WITH TIME ZONE,
    price DOUBLE PRECISION,
    freight_value DOUBLE PRECISION,
    CONSTRAINT fk_order_items_orders FOREIGN KEY (order_id, order_purchase_timestamp)
        REFERENCES orders(order_id, order_purchase_timestamp)
);

CREATE TABLE order_payments (
    order_id TEXT,
    order_purchase_timestamp TIMESTAMP WITH TIME ZONE,
    payment_sequential INT,
    payment_type TEXT,
    payment_installments INT,
    payment_value DOUBLE PRECISION,
    CONSTRAINT fk_order_payments_orders FOREIGN KEY (order_id, order_purchase_timestamp)
        REFERENCES orders(order_id, order_purchase_timestamp)
);

CREATE TABLE order_reviews (
    review_id TEXT PRIMARY KEY,
    order_id TEXT,
    order_purchase_timestamp TIMESTAMP WITH TIME ZONE,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP WITH TIME ZONE,
    review_answer_timestamp TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_order_reviews_orders FOREIGN KEY (order_id, order_purchase_timestamp)
        REFERENCES orders(order_id, order_purchase_timestamp)
);

-- 5. Índices recomendados
CREATE INDEX IF NOT EXISTS idx_customers_unique_id ON customers(customer_unique_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(product_category_name);
CREATE INDEX IF NOT EXISTS idx_orders_purchase_brin ON orders USING BRIN (order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_product_category_trgm ON product_category_name_translation USING GIN (product_category_name gin_trgm_ops);