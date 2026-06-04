{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsopp_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsopp_purpose_id ON {{ this }} (purchase_purpose_id)",
    ]
) }}

WITH orders AS (
    SELECT order_id, erp_order_id, order_number, order_date, sales_channel
    FROM {{ ref('fct_sales_orders') }}
),

purposes AS (
    SELECT * FROM {{ ref('int_sales__order_purchase_purposes') }}
)

SELECT
    o.order_id || ':' || p.purchase_purpose_id AS order_purchase_purpose_key,
    o.order_id,
    o.erp_order_id,
    o.order_number,
    o.order_date,
    p.purchase_purpose_id,
    p.purpose_name

FROM orders o
INNER JOIN purposes p
    ON o.erp_order_id = p.erp_sales_order_id
