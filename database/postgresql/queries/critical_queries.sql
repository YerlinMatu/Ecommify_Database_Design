-- Consultas críticas para Ecommify
-- Ejecutar para obtener planes y tiempos (EXPLAIN ANALYZE)

-- 1) Top 10 clientes por número de órdenes
EXPLAIN ANALYZE
SELECT customer_id, COUNT(*) AS orders_count
FROM orders
GROUP BY customer_id
ORDER BY orders_count DESC
LIMIT 10;

-- 2) Órdenes por día (últimos 30 días)
EXPLAIN ANALYZE
SELECT DATE(order_purchase_timestamp) AS day, COUNT(*) AS orders
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY day
ORDER BY day DESC
LIMIT 30;

-- 3) Valor total por orden (top 10 más altos)
EXPLAIN ANALYZE
SELECT oi.order_id, SUM(oi.price) AS total_value
FROM order_items oi
GROUP BY oi.order_id
ORDER BY total_value DESC
LIMIT 10;

-- 4) Productos más vendidos por ingresos (top 10)
EXPLAIN ANALYZE
SELECT p.product_id, p.product_category_name, SUM(oi.price) AS revenue, COUNT(*) AS qty
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_category_name
ORDER BY revenue DESC
LIMIT 10;

-- 5) Distribución de puntuaciones en reseñas
EXPLAIN ANALYZE
SELECT review_score, COUNT(*) AS cnt
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;
