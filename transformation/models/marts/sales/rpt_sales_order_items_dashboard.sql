{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_items_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_items_product_key ON {{ this }} (product_key)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_items_product_type ON {{ this }} (product_type)",
    ]
) }}

WITH items AS (
    SELECT * FROM {{ ref('fct_sales_order_items') }}
),

orders AS (
    SELECT * FROM {{ ref('rpt_sales_orders_dashboard') }}
),

products AS (
    SELECT * FROM {{ ref('dim_sales_products') }}
)

SELECT
    -- === ITEM GRAIN ===
    i.order_item_id,
    i.order_id,
    i.order_number,
    i.real_created_at,
    i.real_created_at_vn,
    i.order_date,

    -- === ORDER FILTERS ===
    i.customer_id,
    i.customer_name,
    o.customer_age_group,
    o.customer_gender,
    o.customer_default_province,
    o.customer_lead_id,
    o.customer_lead_name,
    o.customer_lead_source_name,
    o.customer_lead_source_platform,
    o.customer_pancake_platform,
    o.customer_pancake_page_name,
    o.customer_lead_budget_label,
    o.customer_lead_demand_label,
    o.customer_lead_status,
    o.customer_lead_qualification_status,
    o.customer_lead_is_converted,
    o.customer_lead_order_group_key,
    o.customer_lead_order_group_rank,
    o.customer_lead_order_group_at,
    o.customer_lead_order_group_date,
    o.is_customer_lead_first_order_group,
    o.primary_sales_person_id,
    o.primary_sales_person_name,
    o.sales_region_name,
    o.sales_city_name,
    o.sales_store_name,
    o.sales_position,
    i.sales_channel,
    i.sales_channel_raw,
    i.payment_status,
    i.fulfillment_status,
    i.processing_status,
    i.order_customer_type,
    i.location_name,
    i.assigned_location_name,
    i.shipping_province,
    i.shipping_district,
    o.price_range,

    -- === PRODUCT ===
    i.product_key,
    i.variant_id,
    i.sku,
    i.barcode,
    COALESCE(p.product_name, i.product_name) AS product_name,
    COALESCE(p.variant_title, i.variant_title) AS variant_title,
    COALESCE(p.product_type, i.product_type) AS product_type,
    COALESCE(p.vendor, i.vendor) AS vendor,
    p.product_id,
    p.design_id,
    p.design_code,
    p.design_type,
    p.fineness,
    p.material_color,
    p.size_type,
    p.ring_size,
    p.estimated_gold_weight,
    p.final_discount_price,
    p.diamond_id,
    p.diamond_carat,
    p.diamond_shape,
    p.diamond_color,
    p.diamond_clarity,
    p.diamond_cut,
    p.diamond_fluorescence,
    p.diamond_edge_size,
    p.diamond_edge_size_display,
    p.moissanite_id,
    p.moissanite_product_group,
    p.moissanite_shape,
    p.moissanite_color,
    p.moissanite_clarity,

    -- === ITEM METRICS ===
    i.quantity,
    i.erp_qty,
    i.haravan_qty,
    i.unit_price,
    i.original_price,
    i.promotion_price,
    i.line_discount_amount,
    i.line_gross_amount,
    i.line_net_amount,
    i.gross_profit,
    i.warehouse,
    i.total_weight,
    i.weight_uom,
    i.valuation_rate,
    i.product_availability_status,
    i.pricing_rules,
    i.is_catalog_matched,
    i.is_missing_variant_id,
    i.is_missing_sku_and_barcode,
    i._db_updated_at

FROM items i
LEFT JOIN orders o
    ON i.order_id = o.order_id
LEFT JOIN products p
    ON i.product_key = p.product_key
