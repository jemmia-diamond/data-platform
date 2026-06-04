{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH staging_orders AS (
    SELECT
        sales_order_id,
        product_categories
    FROM {{ ref('stg_erpnext__sales_orders') }}
),

flattened AS (
    SELECT
        sales_order_id,
        jsonb_array_elements(product_categories) AS cat_item
    FROM staging_orders
    WHERE product_categories IS NOT NULL
      AND product_categories != '[]'::jsonb
),

enriched AS (
    SELECT
        f.sales_order_id,
        f.cat_item ->> 'product_category' AS product_category_id,
        pc.category_name
    FROM flattened f
    LEFT JOIN {{ ref('stg_erpnext__product_categories') }} pc
        ON f.cat_item ->> 'product_category' = pc.product_category_id
    WHERE f.cat_item ->> 'product_category' IS NOT NULL
)

SELECT
    sales_order_id AS erp_sales_order_id,
    product_category_id,
    category_name
FROM enriched
