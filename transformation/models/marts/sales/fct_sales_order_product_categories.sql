{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsopc_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsopc_category_id ON {{ this }} (product_category_id)",
    ]
) }}

WITH orders AS (
    SELECT order_id, erp_order_id, order_number, order_date, sales_channel
    FROM {{ ref('fct_sales_orders') }}
),

categories AS (
    SELECT * FROM {{ ref('int_sales__order_product_categories') }}
)

SELECT
    o.order_id || ':' || c.product_category_id AS order_product_category_key,
    o.order_id,
    o.erp_order_id,
    o.order_number,
    o.order_date,
    c.product_category_id,
    c.category_name

FROM orders o
INNER JOIN categories c
    ON o.erp_order_id = c.erp_sales_order_id
