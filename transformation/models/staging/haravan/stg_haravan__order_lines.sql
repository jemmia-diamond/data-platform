{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint AS order_id,
        created_at::timestamp AS order_created_at,
        jsonb_array_elements(line_items) AS line_item
    FROM {{ source('haravan', 'orders') }}
    WHERE line_items IS NOT NULL AND jsonb_typeof(line_items) = 'array'
)

SELECT
    order_id,
    order_created_at,
    (line_item->>'id')::bigint AS line_item_id,
    (line_item->>'product_id')::bigint AS product_id,
    (line_item->>'variant_id')::bigint AS variant_id,
    line_item->>'sku' AS sku,
    line_item->>'name' AS product_name,
    line_item->>'type' AS product_type,
    line_item->>'vendor' AS vendor,
    (line_item->>'quantity')::int AS quantity,
    (line_item->>'price')::numeric AS price,
    (line_item->>'price_original')::numeric AS original_price,
    (line_item->>'total_discount')::numeric AS total_discount,
    line_item->>'fulfillment_status' AS fulfillment_status
FROM unnested
