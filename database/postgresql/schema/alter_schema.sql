-- ============================================================
-- alter_schema.sql
-- Tipos avanzados, constraints nombrados, CHECK constraints
-- y columna geoespacial.
-- Idempotente: usa IF NOT EXISTS / ADD COLUMN IF NOT EXISTS.
-- Ejecutar DESPUÉS de schema.sql y de cargar los datos.
-- ============================================================

-- Extensiones (ya declaradas en schema.sql, se omiten si existen)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ----------------------------------------------------------
-- 1. TIPOS AVANZADOS
-- ----------------------------------------------------------
-- Columna geoespacial en geolocation (PostGIS Point SRID 4326)
ALTER TABLE geolocation
    ADD COLUMN IF NOT EXISTS geolocation_geom geometry(Point, 4326);

-- Rellenar geom desde lat/lng para filas ya existentes
UPDATE geolocation
SET geolocation_geom = ST_SetSRID(ST_MakePoint(geolocation_lng, geolocation_lat), 4326)
WHERE geolocation_geom IS NULL
  AND geolocation_lat IS NOT NULL
  AND geolocation_lng IS NOT NULL;

-- ----------------------------------------------------------
-- 2. CONSTRAINTS NOMBRADOS — geolocation
-- ----------------------------------------------------------
ALTER TABLE geolocation
    ADD CONSTRAINT IF NOT EXISTS pk_geolocation
        PRIMARY KEY (geolocation_zip_code_prefix);

ALTER TABLE geolocation
    ADD CONSTRAINT IF NOT EXISTS chk_geolocation_lat
        CHECK (geolocation_lat BETWEEN -90  AND  90);

ALTER TABLE geolocation
    ADD CONSTRAINT IF NOT EXISTS chk_geolocation_lng
        CHECK (geolocation_lng BETWEEN -180 AND 180);

-- ----------------------------------------------------------
-- 3. CONSTRAINTS NOMBRADOS — customers
-- ----------------------------------------------------------
ALTER TABLE customers
    ADD CONSTRAINT IF NOT EXISTS fk_customers_geolocation
        FOREIGN KEY (customer_zip_code_prefix)
        REFERENCES geolocation (geolocation_zip_code_prefix)
        ON UPDATE CASCADE ON DELETE SET NULL;

-- ----------------------------------------------------------
-- 4. CONSTRAINTS NOMBRADOS — sellers
-- ----------------------------------------------------------
ALTER TABLE sellers
    ADD CONSTRAINT IF NOT EXISTS fk_sellers_geolocation
        FOREIGN KEY (seller_zip_code_prefix)
        REFERENCES geolocation (geolocation_zip_code_prefix)
        ON UPDATE CASCADE ON DELETE SET NULL;

-- ----------------------------------------------------------
-- 5. CONSTRAINTS NOMBRADOS — orders
-- ----------------------------------------------------------
ALTER TABLE orders
    ADD CONSTRAINT IF NOT EXISTS fk_orders_customers
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE orders
    ADD CONSTRAINT IF NOT EXISTS chk_orders_status
        CHECK (order_status IN (
            'created', 'approved', 'invoiced', 'processing',
            'shipped', 'delivered', 'unavailable', 'canceled'
        ));

-- ----------------------------------------------------------
-- 6. CONSTRAINTS NOMBRADOS — products
-- ----------------------------------------------------------
ALTER TABLE products
    ADD CONSTRAINT IF NOT EXISTS fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation (product_category_name)
        ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE products
    ADD CONSTRAINT IF NOT EXISTS chk_products_weight
        CHECK (product_weight_g IS NULL OR product_weight_g >= 0);

-- ----------------------------------------------------------
-- 7. CONSTRAINTS NOMBRADOS — order_items
-- ----------------------------------------------------------
ALTER TABLE order_items
    ADD CONSTRAINT IF NOT EXISTS fk_order_items_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE order_items
    ADD CONSTRAINT IF NOT EXISTS fk_order_items_products
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE order_items
    ADD CONSTRAINT IF NOT EXISTS fk_order_items_sellers
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE order_items
    ADD CONSTRAINT IF NOT EXISTS chk_order_items_price
        CHECK (price >= 0 AND freight_value >= 0);

-- ----------------------------------------------------------
-- 8. CONSTRAINTS NOMBRADOS — order_payments
-- ----------------------------------------------------------
ALTER TABLE order_payments
    ADD CONSTRAINT IF NOT EXISTS fk_order_payments_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE order_payments
    ADD CONSTRAINT IF NOT EXISTS chk_payment_installments
        CHECK (payment_installments > 0);

ALTER TABLE order_payments
    ADD CONSTRAINT IF NOT EXISTS chk_payment_value
        CHECK (payment_value >= 0);

-- ----------------------------------------------------------
-- 9. CONSTRAINTS NOMBRADOS — order_reviews
-- ----------------------------------------------------------
ALTER TABLE order_reviews
    ADD CONSTRAINT IF NOT EXISTS fk_order_reviews_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE order_reviews
    ADD CONSTRAINT IF NOT EXISTS chk_review_score
        CHECK (review_score BETWEEN 1 AND 5);

-- ----------------------------------------------------------
-- 10. Actualizar estadísticas
-- ----------------------------------------------------------
ANALYZE geolocation;
ANALYZE orders;
ANALYZE order_items;
ANALYZE order_reviews;
ANALYZE products;
