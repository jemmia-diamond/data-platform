{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_order_items_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_order_items_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_order_items_product_key ON {{ this }} (product_key)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_order_items_order_date ON {{ this }} USING brin (order_date)",
    ]
) }}

-- Metabot order_items fact. Grain: 1 row = 1 line item.
-- Source: int_sales__order_items INNER JOIN int_sales__orders (valid-order filter).
-- order_id links to the ORDER GROUP (split_order_group); source_order_number keeps physical order traceability.

WITH valid_orders AS (
    SELECT
        unified_sales_order_id,
        COALESCE(split_order_group, unified_sales_order_id) AS order_id,
        order_number,
        unified_customer_id,
        first_order_at,
        sales_channel
    FROM {{ ref('int_sales__orders') }}
    WHERE {{ metabot_valid_orders_filter() }}
),

items AS (
    SELECT * FROM {{ ref('int_sales__order_items') }}
)

SELECT
    COALESCE(i.erp_sales_order_item_id, i.haravan_line_item_id::text) AS order_item_id,
    o.order_id,
    o.order_number AS source_order_number,
    i.unified_sales_order_id AS source_order_id,
    o.unified_customer_id AS customer_id,
    i.variant_id AS product_key,
    (o.first_order_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS order_date,

    CASE o.sales_channel
        WHEN 'pos-cua-hang-hn' THEN 'POS - Hà Nội'
        WHEN 'pos-cua-hang-hcm' THEN 'POS - Hồ Chí Minh'
        WHEN 'pos cua hang can tho' THEN 'POS - Cần Thơ'
        WHEN 'pos' THEN 'POS - Chưa xác định'
        WHEN 'staff' THEN 'Nhân viên'
        ELSE 'Kênh online'
    END AS sales_channel,

    i.sku,
    i.barcode,
    i.product_name,
    i.variant_title,
    i.product_type,
    i.vendor,

    i.quantity,
    i.unit_price AS unit_price_vnd,
    i.line_gross_amount AS line_gross_amount_vnd,
    i.line_net_amount AS line_net_amount_vnd,
    i.gross_profit AS gross_profit_vnd,

    CASE i.product_availability_status
        WHEN 'Pre-order' THEN 'Hàng order'
        WHEN 'In Stock' THEN 'Hàng có sẵn'
        ELSE 'Chưa xác định'
    END AS product_availability_status

FROM items i
INNER JOIN valid_orders o
    ON i.unified_sales_order_id = o.unified_sales_order_id
