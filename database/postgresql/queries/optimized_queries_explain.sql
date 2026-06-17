-- Consultas optimizadas envueltas en EXPLAIN para medir rendimiento

-- 1) Top 10 clientes por número de órdenes
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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

-- 2) Órdenes por día (últimos 30 días)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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

-- 3) Valor total por orden (Top 10) — eliminación de JOIN innecesario
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH totals AS (
  SELECT order_id, SUM(price) AS total_value
  FROM order_items
  GROUP BY order_id
)
SELECT order_id, total_value
FROM totals
ORDER BY total_value DESC
LIMIT 10;

-- 4) Productos más vendidos por ingresos (Top 10) — pre-agregación antes del JOIN
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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

-- 5) Distribución de puntuaciones en reseñas
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT review_score, COUNT(*) AS cnt
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

-- ============================================================
-- 6) CLTV — pre-agregación en order_items antes del JOIN
--    CAMBIO: en lugar de agregar 112,650 filas de order_items
--    directamente con orders (causando HashAggregate con spill
--    de 7,280 kB en 5 batches), primero se colapsan los items
--    a nivel de order_id (112,650 → ~98,666 filas) y luego se
--    hace el JOIN con orders para obtener customer_id.
--    Esto reduce la cardinalidad del HashAggregate final y
--    evita que PostgreSQL empuje el filtro IS NOT NULL al
--    interior del Index Scan de orders_pkey.
-- ============================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH order_totals AS (
  SELECT order_id, SUM(price) AS revenue
  FROM order_items
  GROUP BY order_id
)
SELECT o.customer_id, SUM(ot.revenue) AS total_revenue
FROM orders o
JOIN order_totals ot ON o.order_id = ot.order_id
WHERE o.customer_id IS NOT NULL
GROUP BY o.customer_id
ORDER BY total_revenue DESC
LIMIT 20;

-- 7) Tiempo medio de entrega — sin cambios (ya era óptima)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_approved_at))/86400.0) AS avg_delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;