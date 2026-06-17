-- ============================================================
-- ÍNDICES REQUERIDOS ANTES DE CORRER LAS QUERIES OPTIMIZADAS
-- ============================================================

-- Para query 1 y 6 (CLTV): GROUP BY customer_id
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders (customer_id);

-- Para query 2: GROUP BY DATE(order_purchase_timestamp)
-- El BRIN que tienes sirve para rangos, pero no para GROUP BY por día
CREATE INDEX IF NOT EXISTS idx_orders_purchase_date
    ON orders (DATE(order_purchase_timestamp));

-- Para query 3: elimina el JOIN innecesario — no requiere índice extra
-- idx_order_items_orderid ya existe ✅

-- Para query 4: cubre JOIN + aggregate en order_items
CREATE INDEX IF NOT EXISTS idx_order_items_product_price
    ON order_items (product_id, price);

-- Para query 5: order_reviews es pequeña, Seq Scan es aceptable
-- No se requiere índice adicional

-- Para query 7: filtra NULLs en dos columnas de orders
CREATE INDEX IF NOT EXISTS idx_orders_delivery_times
    ON orders (order_approved_at, order_delivered_customer_date)
    WHERE order_approved_at IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL;

-- ============================================================
-- QUERIES OPTIMIZADAS
-- ============================================================

-- 1) Top 10 clientes por número de órdenes
-- CAMBIO: ninguno en SQL — el índice idx_orders_customer_id
-- permite Index Scan en lugar de Seq Scan + Hash Aggregate
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    customer_id,
    COUNT(*) AS orders_count
FROM orders
GROUP BY customer_id
ORDER BY orders_count DESC
LIMIT 10;

-- 2) Órdenes por día
-- CAMBIO: usa el índice funcional en DATE(order_purchase_timestamp)
-- evita calcular DATE() en cada fila del Seq Scan
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    DATE(order_purchase_timestamp) AS day,
    COUNT(*)                        AS orders
FROM orders
GROUP BY DATE(order_purchase_timestamp)
ORDER BY day DESC
LIMIT 30;

-- 3) Valor total por orden (Top 10)
-- CAMBIO: elimina el JOIN con orders — es completamente innecesario
-- porque order_id ya está en order_items y no usas ninguna columna de orders
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    order_id,
    SUM(price) AS total_value
FROM order_items
GROUP BY order_id
ORDER BY total_value DESC
LIMIT 10;

-- 4) Productos más vendidos por ingresos
-- CAMBIO: idx_order_items_product_price permite Index Only Scan
-- en order_items sin heap fetch para obtener price
-- El JOIN a products solo trae product_category_name (inevitable)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    p.product_id,
    p.product_category_name,
    SUM(oi.price)  AS revenue,
    COUNT(*)       AS qty
FROM order_items oi
JOIN products p USING (product_id)
GROUP BY p.product_id, p.product_category_name
ORDER BY revenue DESC
LIMIT 10;

-- 5) Distribución de puntuaciones
-- CAMBIO: ninguno — Seq Scan es óptimo para GROUP BY sobre
-- columna de baja cardinalidad (scores 1-5) en tabla pequeña
-- Agregar índice aquí sería contraproducente
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    review_score,
    COUNT(*) AS cnt
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 6) Tiempo medio de entrega
-- CAMBIO: el índice parcial idx_orders_delivery_times filtra
-- los NULLs a nivel de índice — evita Seq Scan + Filter
-- EXTRACT se mantiene igual, no hay forma de pre-computarlo sin MV
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    AVG(
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_approved_at))
        / 86400.0
    ) AS avg_delivery_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;