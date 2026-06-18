{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_stock_variant_id ON {{ this }} (variant_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_stock_location_id ON {{ this }} (location_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_inventory_stock_product_type ON {{ this }} (product_type)",
    ]
) }}

SELECT
    location_id, location_name, is_primary_location,
    variant_id, product_id, product_title, product_type,
    sku, barcode, variant_title, variant_price,
    qty_onhand, qty_commited, qty_incoming, qty_available,
    _db_updated_at
FROM {{ ref('int_inventory__stock_by_location') }}
