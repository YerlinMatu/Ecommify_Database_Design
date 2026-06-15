-- 1. Consulta lenta (sin índices): Join de Órdenes, Ítems y Productos
-- Esta consulta busca el gasto total por categoría de producto para órdenes de 2017
SELECT 
    p.product_category_name, 
    SUM(oi.price) as total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_purchase_timestamp >= '2017-01-01' AND o.order_purchase_timestamp < '2018-01-01'
GROUP BY p.product_category_name;

-- 2. Consulta de Geolocalización
-- Buscar cuántos clientes hay en una ciudad específica
SELECT count(*) 
FROM customers 
WHERE customer_city = 'sao paulo';

-- 3. Análisis de pagos
-- Promedio de pagos por tipo de pago
SELECT payment_type, AVG(payment_value)
FROM order_payments
GROUP BY payment_type;