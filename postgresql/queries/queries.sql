-- 1. CONSULTA ESPACIAL (PostGIS): 
-- Calcula la distancia en kilómetros entre el cliente y el vendedor para un pedido específico.
SELECT 
    o.order_id,
    c.zip_code AS customer_zip,
    s.zip_code AS seller_zip,
    ST_DistanceSphere(c.location, s.location) / 1000 AS distance_km
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_id = 'f1e2d3c4-b5a6-9f8e-7d6c-5b4a3c2d1e0f';

-- 2. CONSULTA JSONB: 
-- Filtra transacciones procesadas específicamente por 'stripe' pagadas a más de 1 cuota (installments).
SELECT 
    order_id, 
    payment_value, 
    gateway_metadata->>'card_brand' AS card_brand 
FROM payments 
WHERE gateway_metadata @> '{"gateway": "stripe"}'
AND (gateway_metadata->>'installments')::int > 1;

-- 3. CONSULTA DE RANGOS (TSTZRANGE): 
-- Encuentra pedidos donde una fecha específica cayó dentro de la ventana de entrega prometida.
SELECT 
    order_id, 
    status, 
    delivery_window 
FROM orders 
WHERE delivery_window @> '2017-12-24 15:00:00+00'::timestamptz;