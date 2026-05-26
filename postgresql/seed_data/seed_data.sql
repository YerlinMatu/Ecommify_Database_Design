-- Insertar Cliente (Usando ST_SetSRID y ST_MakePoint para PostGIS)
INSERT INTO customers (customer_id, zip_code, location) 
VALUES (
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 
    '14409', 
    ST_SetSRID(ST_MakePoint(-46.639292, -23.545621), 4326) -- Longitud, Latitud de Sao Paulo
);

-- Insertar Vendedor
INSERT INTO sellers (seller_id, zip_code, location) 
VALUES (
    'seller_999', 
    '13023', 
    ST_SetSRID(ST_MakePoint(-47.061333, -22.904555), 4326) -- Campinas
);

-- Insertar Pedido (Cayendo en la partición de Diciembre 2017)
INSERT INTO orders (order_id, customer_id, status, created_at, delivery_window) 
VALUES (
    'f1e2d3c4-b5a6-9f8e-7d6c-5b4a3c2d1e0f',
    'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
    'approved',
    '2017-12-15 10:30:00+00',
    '["2017-12-20 00:00:00+00", "2017-12-28 23:59:59+00"]' -- Rango de fechas
);

-- Insertar Items del pedido
INSERT INTO order_items (order_id, order_created_at, product_id, seller_id, price, freight_value) 
VALUES (
    'f1e2d3c4-b5a6-9f8e-7d6c-5b4a3c2d1e0f',
    '2017-12-15 10:30:00+00',
    'prod_8a2b5c',
    'seller_999',
    150.00,
    25.50
);

-- Insertar Pago (Con metadata JSONB)
INSERT INTO payments (order_id, order_created_at, payment_type, payment_value, gateway_metadata) 
VALUES (
    'f1e2d3c4-b5a6-9f8e-7d6c-5b4a3c2d1e0f',
    '2017-12-15 10:30:00+00',
    'credit_card',
    175.50,
    '{"gateway": "stripe", "transaction_id": "txn_123abc", "installments": 3, "card_brand": "visa"}'::jsonb
);