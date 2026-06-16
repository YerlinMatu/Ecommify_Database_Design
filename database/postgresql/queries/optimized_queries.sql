-- Consultas optimizadas para Ecommify
-- Contiene versiones mejoradas de consultas críticas y recomendaciones de índices.
-- NOTAS:
-- 1) Ejecutar índices desde `create_indexes.sql` antes de usar estas consultas para obtener máximo rendimiento.
-- 2) Estas consultas están escritas para aprovechar índices en: orders(order_purchase_timestamp), orders(customer_id),
--    order_items(order_id, product_id), products(product_id), product_category_name_translation(product_category_name)

-- ==================================================
-- A) Top 10 clientes por número de órdenes (optimizada)
-- Usa agregación por `customer_id` con lectura secuencial limitada por índices en `orders`.
-- Recomendado: índice compuesto `idx_orders_customer_purchase (customer_id, order_purchase_timestamp)`
WITH cust_counts AS (
  SELECT customer_id, COUNT(*) AS orders_count
  FROM orders
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
)
SELECT customer_id, orders_count
FROM cust_counts
ORDER BY orders_count DESC
LIMIT 10;

-- ==================================================
-- B) Órdenes por día (últimos N días) — evita agrupar toda la tabla
-- Recomendado: índice BRIN/GIST en order_purchase_timestamp si la tabla es muy grande
SELECT day, orders
FROM (
  SELECT DATE(order_purchase_timestamp) AS day, COUNT(*) AS orders
  FROM orders
  WHERE order_purchase_timestamp >= (CURRENT_DATE - INTERVAL '30 days')
    AND order_purchase_timestamp IS NOT NULL
  GROUP BY day
) t
ORDER BY day DESC
LIMIT 30;

-- ==================================================
-- C) Valor total por orden (Top 10) — agregación en `order_items` (más eficiente que JOIN primero)
-- Recomendado: índice en order_items(order_id) para acelerar la agregación por orden
WITH totals AS (
  SELECT order_id, SUM(price) AS total_value
  FROM order_items
  GROUP BY order_id
)
SELECT order_id, total_value
FROM totals
ORDER BY total_value DESC
LIMIT 10;

-- ==================================================
-- D) Productos más vendidos por ingresos (Top 10)
-- Agregamos por `product_id` y luego hacemos JOIN reducido a `products`.
-- Recomendado: índice compuesto order_items(product_id, price)
WITH prod_rev AS (
  SELECT product_id, SUM(price) AS revenue, COUNT(*) AS qty
  FROM order_items
  GROUP BY product_id
)
SELECT p.product_id, p.product_category_name, pr.revenue, pr.qty
FROM prod_rev pr
JOIN products p ON p.product_id = pr.product_id
ORDER BY pr.revenue DESC
LIMIT 10;

-- ==================================================
-- E) Distribución de puntuaciones en reseñas (optimizada)
-- Si la cardinalidad es baja (scores 1..5), esta consulta será muy rápida
SELECT review_score, COUNT(*) AS cnt
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

-- ==================================================
-- F) Customer Lifetime Value (CLTV) ejemplo (ingresos totales por cliente)
WITH revenue_by_customer AS (
  SELECT o.customer_id, SUM(oi.price) AS revenue
  FROM orders o
  JOIN order_items oi USING (order_id)
  WHERE o.customer_id IS NOT NULL
  GROUP BY o.customer_id
)
SELECT customer_id, revenue
FROM revenue_by_customer
ORDER BY revenue DESC
LIMIT 20;

-- ==================================================
-- G) Tiempo medio de entrega (aprobación -> entrega al cliente) — evita operaciones en columnas NULL
SELECT AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_approved_at))/86400.0) AS avg_delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- ==================================================
-- Recomendaciones de índices (ejecutar una sola vez, ya incluidas en create_indexes.sql):
-- CREATE INDEX idx_orders_purchase_brin ON orders USING BRIN (order_purchase_timestamp);
-- CREATE INDEX idx_orders_customer_purchase ON orders (customer_id, order_purchase_timestamp);
-- CREATE INDEX idx_order_items_orderid ON order_items (order_id);
-- CREATE INDEX idx_order_items_productid ON order_items (product_id);
-- CREATE INDEX idx_product_category_trgm ON product_category_name_translation USING GIN (product_category_name gin_trgm_ops);
