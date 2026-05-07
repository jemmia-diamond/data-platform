{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH haravan AS (
    SELECT * FROM {{ ref('stg_haravan__order_lines') }}
),

erpnext AS (
    SELECT * FROM {{ ref('stg_erpnext__sales_order_items') }}
)

SELECT
    -- Keys & Identity
    COALESCE(h.order_id, e.haravan_order_id::bigint) AS order_id,
    e.sales_order_id AS erp_sales_order_id,
    h.line_item_id AS haravan_line_item_id,
    e.sales_order_item_id AS erp_sales_order_item_id,
    
    -- Product Metadata (Priority: Haravan)
    COALESCE(h.sku, e.sku) AS sku,
    COALESCE(h.barcode, e.barcode) AS barcode,
    COALESCE(h.product_name, e.item_name) AS product_name,
    COALESCE(h.variant_title, e.variant_title) AS variant_title,
    COALESCE(h.variant_id, e.haravan_variant_id) AS variant_id,
    h.product_type,
    h.vendor,
    e.image,
    
    -- Quantities
    COALESCE(h.quantity, e.qty) AS quantity,
    e.qty AS erp_qty,
    h.quantity AS haravan_qty,

    -- Financials (Transaction Currency - Priority: Haravan)
    COALESCE(h.price, e.rate) AS unit_price,
    COALESCE(h.original_price, e.price_list_rate) AS original_price,
    h.promotion_price,
    COALESCE(h.total_discount, e.discount_amount) AS line_discount_amount,
    COALESCE(h.price * h.quantity, e.amount) AS line_gross_amount,
    COALESCE((h.price * h.quantity) - COALESCE(h.total_discount, 0), e.net_amount) AS line_net_amount,
    
    -- ERP Specific Details (Jewelry Context - Full Schema Retained)
    e.serial_numbers,
    e.serial,
    e.diamond_details,
    e.product_details,
    e.warehouse,
    e.total_weight,
    e.weight_uom,
    e.valuation_rate,
    e.gross_profit,
    e.promotion_1,
    e.promotion_2,
    e.promotion_3,
    e.promotion_4,
    e.promotion_5,
    e.new_promotions,
    e.product_availability_status,
    e.pricing_rules,
    
    -- Status & Metadata
    COALESCE(h.fulfillment_status, e.item_type) AS status_info,
    e.transaction_date,
    h.applied_discounts_json,
    COALESCE(h._db_updated_at, e._db_updated_at) AS _db_updated_at

FROM haravan h
FULL OUTER JOIN erpnext e 
    ON h.order_id::text = e.haravan_order_id
    AND h.line_item_pos = e.line_item_idx
