{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS order_id,
    order_number,
    created_at::timestamp AS created_at,
    
    -- Order statuses
    financial_status,
    fulfillment_status,
    
    -- Payment & Channel
    gateway_code,
    gateway AS gateway_name,
    source_name AS channel,
    
    -- Revenue metrics
    subtotal_price::numeric AS subtotal_price,
    total_price::numeric AS total_price,
    total_discounts::numeric AS total_discounts,
    
    -- Extract customer info from JSON to avoid deep nesting
    (customer->>'id')::bigint AS customer_id,
    
    -- Extract shipping information
    shipping_address->>'province' AS shipping_province,
    shipping_address->>'district' AS shipping_district,
    
    -- Location processing info
    assigned_location_id::bigint AS assigned_location_id,
    location_name AS assigned_location_name,
    
    -- Chained reference fields (Used for recursive CTE lineage)
    (prev_order_id)::bigint AS prev_order_id,
    (prev_order_date)::timestamp AS prev_order_date,
    
    (ref_order_id)::bigint AS ref_order_id,
    (ref_order_date)::timestamp AS ref_order_date

FROM {{ source('haravan', 'orders') }}
