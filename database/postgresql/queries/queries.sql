-- ============================================================
--  QUERIES CRÍTICAS - OLIST E-COMMERCE
--  Dataset: Brazilian E-Commerce (Olist)
--  PostgreSQL / Supabase
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Revenue total y número de órdenes por mes
-- Útil para: análisis de tendencias de ventas en el tiempo
-- ------------------------------------------------------------
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS mes,
    COUNT(DISTINCT o.order_id)                      AS total_ordenes,
    ROUND(SUM(oi.price)::NUMERIC, 2)                AS revenue_productos,
    ROUND(SUM(oi.freight_value)::NUMERIC, 2)        AS revenue_flete,
    ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS revenue_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ------------------------------------------------------------
-- Q2: Top 10 sellers por revenue con score promedio
-- Útil para: identificar vendedores estrella y correlación calidad/ventas
-- ------------------------------------------------------------
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)              AS total_ordenes,
    ROUND(SUM(oi.price)::NUMERIC, 2)         AS revenue,
    ROUND(AVG(r.review_score)::NUMERIC, 2)   AS avg_score,
    COUNT(r.review_id)                       AS total_reseñas
FROM sellers s
JOIN order_items oi ON s.seller_id  = oi.seller_id
JOIN orders o       ON oi.order_id  = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state
ORDER BY revenue DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Q3: Satisfacción del cliente por categoría de producto
-- Útil para: detectar categorías con problemas de calidad
-- ------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS categoria,
    COUNT(r.review_id)                             AS total_reseñas,
    ROUND(AVG(r.review_score)::NUMERIC, 2)         AS avg_score,
    COUNT(CASE WHEN r.review_score = 5 THEN 1 END) AS reseñas_5_estrellas,
    COUNT(CASE WHEN r.review_score <= 2 THEN 1 END) AS reseñas_negativas
FROM order_reviews r
JOIN order_items oi ON r.order_id = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY 1
HAVING COUNT(r.review_id) >= 50
ORDER BY avg_score DESC;

-- ------------------------------------------------------------
-- Q4: Tiempo de entrega real vs estimado por estado
-- Útil para: análisis logístico y eficiencia de entrega por región
-- ------------------------------------------------------------
SELECT
    c.customer_state                                        AS estado,
    COUNT(o.order_id)                                       AS total_ordenes,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date
            - o.order_purchase_timestamp)) / 86400
    )::NUMERIC, 1)                                          AS dias_entrega_real,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (o.order_estimated_delivery_date
            - o.order_purchase_timestamp)) / 86400
    )::NUMERIC, 1)                                          AS dias_entrega_estimada,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (o.order_estimated_delivery_date
            - o.order_delivered_customer_date)) / 86400
    )::NUMERIC, 1)                                          AS dias_adelanto_retraso
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY 1
ORDER BY dias_entrega_real DESC;

-- ------------------------------------------------------------
-- Q5: Métodos de pago más usados y valor promedio
-- Útil para: análisis financiero y comportamiento de pago
-- ------------------------------------------------------------
SELECT
    payment_type,
    COUNT(*)                                      AS total_transacciones,
    ROUND(AVG(payment_value)::NUMERIC, 2)         AS valor_promedio,
    ROUND(SUM(payment_value)::NUMERIC, 2)         AS valor_total,
    ROUND(AVG(payment_installments)::NUMERIC, 1)  AS cuotas_promedio,
    MAX(payment_installments)                     AS max_cuotas
FROM order_payments
WHERE payment_value > 0
GROUP BY payment_type
ORDER BY total_transacciones DESC;

-- ------------------------------------------------------------
-- Q6: Tasa de recompra — cuántos clientes compran más de una vez
-- Útil para: análisis de retención y fidelización
-- ------------------------------------------------------------
SELECT
    ordenes_por_cliente,
    COUNT(*)                                          AS cantidad_clientes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS ordenes_por_cliente
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) sub
GROUP BY ordenes_por_cliente
ORDER BY ordenes_por_cliente;

-- ------------------------------------------------------------
-- Q7: Top 15 categorías por volumen y revenue
-- Útil para: análisis de demanda y mix de productos
-- ------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS categoria,
    COUNT(oi.order_item_id)                  AS unidades_vendidas,
    ROUND(SUM(oi.price)::NUMERIC, 2)         AS revenue_total,
    ROUND(AVG(oi.price)::NUMERIC, 2)         AS precio_promedio,
    ROUND(AVG(oi.freight_value)::NUMERIC, 2) AS flete_promedio
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue_total DESC
LIMIT 15;