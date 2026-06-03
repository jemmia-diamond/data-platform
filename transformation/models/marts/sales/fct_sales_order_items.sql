{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsi_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsi_product_key ON {{ this }} (product_key)",
      "CREATE INDEX IF NOT EXISTS idx_fsi_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsi_order_product ON {{ this }} (order_id, product_key)",
    ]
) }}

WITH items AS (
    SELECT * FROM {{ ref('int_sales__order_items') }}
),

orders AS (
    SELECT * FROM {{ ref('fct_sales_orders') }}
),

catalog_variants AS (
    SELECT variant_id FROM {{ ref('int_catalog__variants') }}
)

SELECT
    i.unified_sales_order_item_id AS order_item_id,
    o.order_id,
    o.order_number,
    o.real_created_at,
    o.order_date,
    o.customer_id,
    o.customer_name,
    o.sales_channel,
    o.sales_channel_raw,

    i.variant_id AS product_key,
    i.variant_id,
    i.sku,
    i.barcode,
    i.product_name,
    i.variant_title,
    i.product_type,
    i.vendor,

    i.erp_sales_order_id,
    i.haravan_order_id,
    i.haravan_line_item_id,
    i.erp_sales_order_item_id,

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
    i.serial_numbers,
    i.serial,
    i.diamond_details,
    i.product_details,

    i.promotion_1,
    i.promotion_2,
    i.promotion_3,
    i.promotion_4,
    i.promotion_5,
    i.new_promotions,
    CASE i.product_availability_status
        WHEN 'Pre-order' THEN 'Hàng order'
        WHEN 'In Stock' THEN 'Hàng có sẵn'
        ELSE 'Chưa xác định'
    END AS product_availability_status,
    i.pricing_rules,

    i.status_info,
    i.transaction_date,
    i.applied_discounts_json,

    o.payment_status,
    o.fulfillment_status,
    o.processing_status,
    o.order_customer_type,
    o.location_name,
    o.assigned_location_name,
    o.shipping_province,
    o.shipping_district,

    cv.variant_id IS NOT NULL AS is_catalog_matched,
    i.variant_id IS NULL AS is_missing_variant_id,
    NULLIF(i.sku, '') IS NULL AND NULLIF(i.barcode, '') IS NULL AS is_missing_sku_and_barcode,

    i._db_updated_at

FROM items i
INNER JOIN orders o
    ON i.unified_sales_order_id = o.order_id
LEFT JOIN catalog_variants cv
    ON i.variant_id = cv.variant_id
