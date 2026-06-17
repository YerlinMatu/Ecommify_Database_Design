-- Índices recomendados para Ecommify
-- Ejecutar AFTER data load (más rápido si se crean tras la carga masiva)

-- B-tree para claves y joins
CREATE INDEX IF NOT EXISTS idx_customers_customer_unique_id ON customers (customer_unique_id);
CREATE INDEX IF NOT EXISTS idx_customers_zip ON customers (customer_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_sellers_zip ON sellers (seller_zip_code_prefix);

-- Índices en columnas usadas para JOINs/ búsquedas por order
CREATE INDEX IF NOT EXISTS idx_order_items_orderid    ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_productid  ON order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_orderid ON order_payments (order_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_orderid  ON order_reviews (order_id);

-- BRIN para series temporales grandes
CREATE INDEX IF NOT EXISTS idx_orders_purchase_brin ON orders USING BRIN (order_purchase_timestamp);

-- GiST para geospatial queries (PostGIS)
-- Requiere haber ejecutado alter_schema.sql primero (agrega la columna geolocation_geom)
CREATE INDEX IF NOT EXISTS idx_geolocation_geom_gist ON geolocation USING GIST (geolocation_geom);

-- GIN + pg_trgm para búsquedas de texto en categorías o nombre de producto
CREATE INDEX IF NOT EXISTS idx_product_category_trgm ON product_category_name_translation USING GIN (product_category_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_category ON products (product_category_name);

-- Índice compuesto frecuente
-- NOTE: index compuesto (customer_id, order_purchase_timestamp) puede
-- empeorar agregaciones globales que escanean la tabla completa (heap fetchs).
-- Se omite por defecto en el benchmark; si lo deseas, descomenta la línea
-- siguiente.
-- CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase ON orders (customer_id, order_purchase_timestamp);
-- Alternativa ligera: índice simple sobre customer_id (descomentar si se quiere probar)
-- CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);

-- Indices adicionales recomendados para acelerar la consulta CLTV
-- (SELECT o.customer_id, SUM(oi.price) ... JOIN order_items oi ON o.order_id = oi.order_id)
-- 1) Hacer posible un index-only scan en `orders` cuando se accede por `order_id`
CREATE INDEX IF NOT EXISTS idx_orders_orderid_customerid ON orders (order_id, customer_id);

-- 2) Permitir agregación por `order_id` leyendo el precio directamente desde el índice
--    (reduce heap fetches y favorece index-only scans sobre order_items)
CREATE INDEX IF NOT EXISTS idx_order_items_orderid_price ON order_items (order_id) INCLUDE (price);

-- 3) Índice simple sobre customer_id para acelerar el GROUP BY/ORDER BY por customer
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);

-- Recolectar estadísticas tras crear índices
ANALYZE;
