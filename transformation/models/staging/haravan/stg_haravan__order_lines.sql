{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint AS order_id,
        created_at::timestamp AS order_created_at,
        jsonb_array_elements(line_items) AS line_item,
        _db_updated_at
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
    line_item->>'barcode' AS barcode,
    line_item->>'name' AS product_name,
    line_item->>'title' AS product_title,
    line_item->>'variant_title' AS variant_title,
    line_item->>'type' AS product_type,
    line_item->>'vendor' AS vendor,
    (line_item->>'quantity')::int AS quantity,
    
    -- Financials
    (line_item->>'price')::numeric AS price,
    (line_item->>'price_original')::numeric AS original_price,
    (line_item->>'price_promotion')::numeric AS promotion_price,
    (line_item->>'total_discount')::numeric AS total_discount,
    (line_item->>'ma_cost_amount')::numeric AS ma_cost_amount,
    
    -- Status
    line_item->>'fulfillment_status' AS fulfillment_status,
    (line_item->>'gift_card')::boolean AS is_gift_card,
    (line_item->>'taxable')::boolean AS is_taxable,
    
    -- Metadata & Row Indexing
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY (line_item->>'id')::bigint) AS line_item_pos,
    line_item->'properties' AS properties_json,
    line_item->'applied_discounts' AS applied_discounts_json,
    _db_updated_at::timestamp AS _db_updated_at

FROM unnested
