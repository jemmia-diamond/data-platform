{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_attributes_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_attributes_order_date ON {{ this }} USING brin (order_date)",
    ]
) }}

WITH orders AS (
    SELECT order_id, order_number, order_date
    FROM {{ ref('fct_sales_orders') }}
),

categories AS (
    SELECT
        order_id,
        COUNT(DISTINCT product_category_id) AS product_category_count,
        STRING_AGG(DISTINCT category_name, ' + ' ORDER BY category_name) AS product_categories
    FROM {{ ref('fct_sales_order_product_categories') }}
    GROUP BY 1
),

purposes AS (
    SELECT
        order_id,
        COUNT(DISTINCT purchase_purpose_id) AS purchase_purpose_count,
        STRING_AGG(DISTINCT purpose_name, ' + ' ORDER BY purpose_name) AS purchase_purposes
    FROM {{ ref('fct_sales_order_purchase_purposes') }}
    GROUP BY 1
)

SELECT
    o.order_id,
    o.order_number,
    o.order_date,
    COALESCE(c.product_category_count, 0) AS product_category_count,
    COALESCE(c.product_categories, 'Chưa xác định') AS product_categories,
    COALESCE(p.purchase_purpose_count, 0) AS purchase_purpose_count,
    COALESCE(p.purchase_purposes, 'Chưa xác định') AS purchase_purposes
FROM orders o
LEFT JOIN categories c
    ON o.order_id = c.order_id
LEFT JOIN purposes p
    ON o.order_id = p.order_id

