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
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_geolocation') THEN
        IF EXISTS (
            SELECT 1 FROM (
                SELECT geolocation_zip_code_prefix, COUNT(*) AS cnt
                FROM geolocation
                GROUP BY geolocation_zip_code_prefix
                HAVING COUNT(*) > 1
            ) dups
        ) THEN
            RAISE NOTICE 'Skipping creation of pk_geolocation: duplicate geolocation_zip_code_prefix values exist';
        ELSE
            EXECUTE 'ALTER TABLE geolocation ADD CONSTRAINT pk_geolocation PRIMARY KEY (geolocation_zip_code_prefix)';
        END IF;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_geolocation_lat') THEN
        EXECUTE 'ALTER TABLE geolocation ADD CONSTRAINT chk_geolocation_lat CHECK (geolocation_lat BETWEEN -90 AND 90)';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_geolocation_lng') THEN
        EXECUTE 'ALTER TABLE geolocation ADD CONSTRAINT chk_geolocation_lng CHECK (geolocation_lng BETWEEN -180 AND 180)';
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 3. CONSTRAINTS NOMBRADOS — customers
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_customers_geolocation') THEN
        IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_geolocation') THEN
            EXECUTE $sql$ALTER TABLE customers
                ADD CONSTRAINT fk_customers_geolocation
                FOREIGN KEY (customer_zip_code_prefix)
                REFERENCES geolocation (geolocation_zip_code_prefix)
                ON UPDATE CASCADE ON DELETE SET NULL$sql$;
        ELSE
            RAISE NOTICE 'Skipping fk_customers_geolocation: referenced unique constraint pk_geolocation does not exist';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 4. CONSTRAINTS NOMBRADOS — sellers
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_sellers_geolocation') THEN
        IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'pk_geolocation') THEN
            EXECUTE $sql$ALTER TABLE sellers
                ADD CONSTRAINT fk_sellers_geolocation
                FOREIGN KEY (seller_zip_code_prefix)
                REFERENCES geolocation (geolocation_zip_code_prefix)
                ON UPDATE CASCADE ON DELETE SET NULL$sql$;
        ELSE
            RAISE NOTICE 'Skipping fk_sellers_geolocation: referenced unique constraint pk_geolocation does not exist';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 5. CONSTRAINTS NOMBRADOS — orders
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_customers') THEN
        EXECUTE $sql$ALTER TABLE orders
            ADD CONSTRAINT fk_orders_customers
            FOREIGN KEY (customer_id)
            REFERENCES customers (customer_id)
            ON UPDATE CASCADE ON DELETE RESTRICT$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_status') THEN
        EXECUTE $sql$ALTER TABLE orders
            ADD CONSTRAINT chk_orders_status
            CHECK (order_status IN ('created','approved','invoiced','processing','shipped','delivered','unavailable','canceled'))$sql$;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 6. CONSTRAINTS NOMBRADOS — products
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_products_category') THEN
        EXECUTE $sql$ALTER TABLE products
            ADD CONSTRAINT fk_products_category
            FOREIGN KEY (product_category_name)
            REFERENCES product_category_name_translation (product_category_name)
            ON UPDATE CASCADE ON DELETE SET NULL$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_weight') THEN
        IF EXISTS (SELECT 1 FROM products WHERE product_weight_g IS NOT NULL AND product_weight_g < 0) THEN
            RAISE NOTICE 'Skipping chk_products_weight: violating rows exist in products';
        ELSE
            EXECUTE 'ALTER TABLE products ADD CONSTRAINT chk_products_weight CHECK (product_weight_g IS NULL OR product_weight_g >= 0)';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 7. CONSTRAINTS NOMBRADOS — order_items
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_items_orders') THEN
        EXECUTE $sql$ALTER TABLE order_items
            ADD CONSTRAINT fk_order_items_orders
            FOREIGN KEY (order_id) REFERENCES orders (order_id)
            ON UPDATE CASCADE ON DELETE CASCADE$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_items_products') THEN
        EXECUTE $sql$ALTER TABLE order_items
            ADD CONSTRAINT fk_order_items_products
            FOREIGN KEY (product_id) REFERENCES products (product_id)
            ON UPDATE CASCADE ON DELETE RESTRICT$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_items_sellers') THEN
        EXECUTE $sql$ALTER TABLE order_items
            ADD CONSTRAINT fk_order_items_sellers
            FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
            ON UPDATE CASCADE ON DELETE RESTRICT$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_order_items_price') THEN
        IF EXISTS (SELECT 1 FROM order_items WHERE (price IS NOT NULL AND price < 0) OR (freight_value IS NOT NULL AND freight_value < 0)) THEN
            RAISE NOTICE 'Skipping chk_order_items_price: violating rows exist in order_items';
        ELSE
            EXECUTE 'ALTER TABLE order_items ADD CONSTRAINT chk_order_items_price CHECK (price >= 0 AND freight_value >= 0)';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 8. CONSTRAINTS NOMBRADOS — order_payments
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_payments_orders') THEN
        EXECUTE $sql$ALTER TABLE order_payments
            ADD CONSTRAINT fk_order_payments_orders
            FOREIGN KEY (order_id) REFERENCES orders (order_id)
            ON UPDATE CASCADE ON DELETE CASCADE$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_payment_installments') THEN
        IF EXISTS (SELECT 1 FROM order_payments WHERE payment_installments IS NOT NULL AND payment_installments <= 0) THEN
            RAISE NOTICE 'Skipping chk_payment_installments: violating rows exist in order_payments';
        ELSE
            EXECUTE 'ALTER TABLE order_payments ADD CONSTRAINT chk_payment_installments CHECK (payment_installments > 0)';
        END IF;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_payment_value') THEN
        IF EXISTS (SELECT 1 FROM order_payments WHERE payment_value IS NOT NULL AND payment_value < 0) THEN
            RAISE NOTICE 'Skipping chk_payment_value: violating rows exist in order_payments';
        ELSE
            EXECUTE 'ALTER TABLE order_payments ADD CONSTRAINT chk_payment_value CHECK (payment_value >= 0)';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 9. CONSTRAINTS NOMBRADOS — order_reviews
-- ----------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_order_reviews_orders') THEN
        EXECUTE $sql$ALTER TABLE order_reviews
            ADD CONSTRAINT fk_order_reviews_orders
            FOREIGN KEY (order_id) REFERENCES orders (order_id)
            ON UPDATE CASCADE ON DELETE CASCADE$sql$;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_review_score') THEN
        IF EXISTS (SELECT 1 FROM order_reviews WHERE review_score IS NOT NULL AND (review_score < 1 OR review_score > 5)) THEN
            RAISE NOTICE 'Skipping chk_review_score: violating rows exist in order_reviews';
        ELSE
            EXECUTE 'ALTER TABLE order_reviews ADD CONSTRAINT chk_review_score CHECK (review_score BETWEEN 1 AND 5)';
        END IF;
    END IF;
END
$$;

-- ----------------------------------------------------------
-- 10. Actualizar estadísticas
-- ----------------------------------------------------------
ANALYZE geolocation;
ANALYZE orders;
ANALYZE order_items;
ANALYZE order_reviews;
ANALYZE products;
