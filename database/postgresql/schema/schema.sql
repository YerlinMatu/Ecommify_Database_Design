CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             FLOAT,
    geolocation_lng             FLOAT,
    geolocation_city            VARCHAR(100),
    geolocation_state           VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS product_category_name_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS customers (
    customer_id              VARCHAR(50) PRIMARY KEY,
    customer_unique_id       VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city            VARCHAR(100),
    customer_state           VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS sellers (
    seller_id              VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city            VARCHAR(100),
    seller_state           VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS products (
    product_id                 VARCHAR(50) PRIMARY KEY,
    product_category_name      VARCHAR(100) REFERENCES product_category_name_translation(product_category_name),
    product_name_lenght        INT,
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           FLOAT,
    product_length_cm          FLOAT,
    product_height_cm          FLOAT,
    product_width_cm           FLOAT
);

CREATE TABLE IF NOT EXISTS orders (
    order_id                      VARCHAR(50) PRIMARY KEY,
    customer_id                   VARCHAR(50) REFERENCES customers(customer_id),
    order_status                  VARCHAR(30),
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id            VARCHAR(50) REFERENCES orders(order_id),
    order_item_id       INT,
    product_id          VARCHAR(50) REFERENCES products(product_id),
    seller_id           VARCHAR(50) REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               FLOAT,
    freight_value       FLOAT,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS order_payments (
    order_id             VARCHAR(50) REFERENCES orders(order_id),
    payment_sequential   INT,
    payment_type         VARCHAR(30),
    payment_installments INT,
    payment_value        FLOAT,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS order_reviews (
    review_id               VARCHAR(50) PRIMARY KEY,
    order_id                VARCHAR(50) REFERENCES orders(order_id),
    review_score            INT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Permisos para inserción desde la anon key
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO anon;