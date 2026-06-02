{{ config(
    materialized='materialized_view',
    schema='marts_sales'
) }}

WITH catalog_variants AS (
    SELECT * FROM {{ ref('int_catalog__variants') }}
),

catalog_products AS (
    SELECT * FROM {{ ref('int_catalog__products') }}
)

SELECT
    v.variant_id AS product_key,
    v.variant_id,
    v.product_id,
    v.sku,
    v.barcode,
    v.product_title AS product_name,
    v.variant_title,
    v.product_type,
    v.product_handle,
    v.vendor,
    v.published_scope,
    v.published_at,
    v.price,
    v.compare_at_price,
    v.inventory_quantity,
    v.qty_onhand,
    v.qty_commited,
    v.qty_incoming,
    v.qty_available,
    p.design_id,
    COALESCE(v.design_code, p.design_code) AS design_code,
    v.design_type,
    v.fineness,
    v.material_color,
    v.size_type,
    v.ring_size,
    COALESCE(v.estimated_gold_weight, p.estimated_gold_weight) AS estimated_gold_weight,
    v.final_discount_price,
    v.diamond_id,
    v.diamond_carat,
    v.diamond_shape,
    v.diamond_color,
    v.diamond_clarity,
    v.diamond_cut,
    v.diamond_cogs,
    v.diamond_vendor,
    v.report_lab,
    v.report_no,
    v.moissanite_id,
    v.moissanite_product_group,
    v.moissanite_shape,
    v.moissanite_color,
    v.moissanite_clarity
FROM catalog_variants v
LEFT JOIN catalog_products p
    ON v.product_id = p.product_id
