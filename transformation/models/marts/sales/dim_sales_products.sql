{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_dsp_product_key ON {{ this }} (product_key)",
      "CREATE INDEX IF NOT EXISTS idx_dsp_product_id ON {{ this }} (product_id)",
      "CREATE INDEX IF NOT EXISTS idx_dsp_product_type ON {{ this }} (product_type)",
    ]
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
    {{ filter_text('v.product_title') }} AS product_name,
    {{ filter_text('v.variant_title') }} AS variant_title,
    {{ filter_text('v.product_type') }} AS product_type,
    v.product_handle,
    {{ filter_text('v.vendor') }} AS vendor,
    {{ filter_text('v.published_scope') }} AS published_scope,
    v.published_at,
    v.price,
    v.compare_at_price,
    v.inventory_quantity,
    v.qty_onhand,
    v.qty_commited,
    v.qty_incoming,
    v.qty_available,
    p.design_id,
    {{ filter_text('COALESCE(v.design_code, p.design_code)') }} AS design_code,
    {{ filter_text('v.design_type') }} AS design_type,
    {{ filter_text('v.fineness') }} AS fineness,
    {{ filter_text('v.material_color') }} AS material_color,
    {{ filter_text('v.size_type') }} AS size_type,
    {{ filter_text('v.ring_size') }} AS ring_size,
    COALESCE(v.estimated_gold_weight, p.estimated_gold_weight) AS estimated_gold_weight,
    v.final_discount_price,
    v.diamond_id,
    v.diamond_carat,
    {{ filter_text('v.diamond_shape', 'Không áp dụng') }} AS diamond_shape,
    {{ filter_text('v.diamond_color', 'Không áp dụng') }} AS diamond_color,
    {{ filter_text('v.diamond_clarity', 'Không áp dụng') }} AS diamond_clarity,
    {{ filter_text('v.diamond_cut', 'Không áp dụng') }} AS diamond_cut,
    {{ filter_text('v.diamond_fluorescence', 'Không áp dụng') }} AS diamond_fluorescence,
    v.diamond_cogs,
    v.diamond_vendor,
    v.report_lab,
    v.report_no,
    v.diamond_edge_size_1,
    v.diamond_edge_size_2,
    v.diamond_edge_size,
    {{ filter_text('v.diamond_edge_size_display', 'Không áp dụng') }} AS diamond_edge_size_display,
    v.moissanite_id,
    {{ filter_text('v.moissanite_product_group', 'Không áp dụng') }} AS moissanite_product_group,
    {{ filter_text('v.moissanite_shape', 'Không áp dụng') }} AS moissanite_shape,
    {{ filter_text('v.moissanite_color', 'Không áp dụng') }} AS moissanite_color,
    {{ filter_text('v.moissanite_clarity', 'Không áp dụng') }} AS moissanite_clarity
FROM catalog_variants v
LEFT JOIN catalog_products p
    ON v.product_id = p.product_id
