-- Consultas baseline (no optimizaciones específicas) — preparadas para EXPLAIN
-- 1) Top 10 clientes por número de órdenes (baseline)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT customer_id, COUNT(*) AS orders_count
FROM orders
GROUP BY customer_id
ORDER BY orders_count DESC
LIMIT 10;

-- 2) Órdenes por día (últimos 30 días) - baseline (agrupa toda la tabla)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DATE(order_purchase_timestamp) AS day, COUNT(*) AS orders
FROM orders
GROUP BY day
ORDER BY day DESC
LIMIT 30;

-- 3) Valor total por orden (Top 10) - baseline con JOIN innecesario
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT oi.order_id, SUM(oi.price) AS total_value
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
GROUP BY oi.order_id
ORDER BY total_value DESC
LIMIT 10;

-- 4) Productos más vendidos por ingresos (Top 10) - agregación con JOIN directo
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.product_id, p.product_category_name, SUM(oi.price) AS revenue, COUNT(*) AS qty
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_category_name
ORDER BY revenue DESC
LIMIT 10;

-- 5) Distribución de puntuaciones en reseñas (baseline)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT review_score, COUNT(*) AS cnt
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- 7) Tiempo medio de entrega (baseline)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_approved_at))/86400.0) AS avg_delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;