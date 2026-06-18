{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_serials_variant_id ON {{ this }} (variant_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_serials_serial_number ON {{ this }} (serial_number)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_serials_stock_location ON {{ this }} (stock_location)",
    ]
) }}

WITH serials AS (SELECT * FROM {{ ref('int_inventory__serials') }}),
products AS (SELECT product_key, product_name, design_code FROM {{ ref('dim_metabot_products') }})

SELECT
    s.item_id,
    s.serial_number,
    s.variant_id,
    s.item_name,
    s.displayed_title,
    p.product_name,
    COALESCE(s.design_code, p.design_code) AS design_code, -- Use design_code from products if serials has none
    s.category,
    s.stock_location,
    s.fulfillment_status_value,
    s.gold_weight,
    s.diamond_weight,
    s.price,
    s.cogs,
    s.quantity,
    s.barcode,
    s.sku,
    s.supplier,
    s.is_have_invoice,
    s.order_id,
    s.stock_id,
    s.arrival_date,
    s.created_at,
    s.updated_at
FROM serials s
LEFT JOIN products p
    ON s.variant_id = p.product_key
