-- Consultas optimizadas envueltas en EXPLAIN para medir rendimiento
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

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT review_score, COUNT(*) AS cnt
FROM order_reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_approved_at))/86400.0) AS avg_delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;
