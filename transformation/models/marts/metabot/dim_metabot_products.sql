{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot product dimension. Grain: 1 row = 1 variant (product_key = variant_id).
-- Source: int_catalog__variants (Haravan primary) + int_catalog__products (design enrichment).
-- Full decouple from marts_sales.dim_sales_products.

WITH variants AS (
    SELECT * FROM {{ ref('int_catalog__variants') }}
),

products AS (
    SELECT product_id, design_code, estimated_gold_weight
    FROM {{ ref('int_catalog__products') }}
)

SELECT
    v.variant_id AS product_key,
    v.product_id,
    v.sku,
    v.barcode,
    v.product_title AS product_name,
    v.variant_title,
    v.product_type,
    v.vendor,
    v.price AS price_vnd,
    v.compare_at_price AS compare_at_price_vnd,
    v.inventory_quantity,
    v.qty_available,
    COALESCE(v.design_code, p.design_code) AS design_code,
    v.design_type,
    v.fineness,
    v.material_color,
    v.ring_size,
    COALESCE(v.estimated_gold_weight, p.estimated_gold_weight) AS estimated_gold_weight,
    v.diamond_carat,
    v.diamond_shape,
    v.diamond_color,
    v.diamond_clarity,
    v.moissanite_shape,
    v.moissanite_color
FROM variants v
LEFT JOIN products p
    ON v.product_id = p.product_id
