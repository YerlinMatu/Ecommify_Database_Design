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
CREATE INDEX IF NOT EXISTS idx_orders_customer_purchase ON orders (customer_id, order_purchase_timestamp);

-- Recolectar estadísticas tras crear índices
ANALYZE;
