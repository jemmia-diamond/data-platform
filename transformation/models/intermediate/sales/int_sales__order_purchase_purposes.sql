{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH staging_orders AS (
    SELECT
        sales_order_id,
        sales_order_purposes
    FROM {{ ref('stg_erpnext__sales_orders') }}
),

flattened AS (
    SELECT
        sales_order_id,
        jsonb_array_elements(sales_order_purposes) AS purpose_item
    FROM staging_orders
    WHERE sales_order_purposes IS NOT NULL
      AND sales_order_purposes != '[]'::jsonb
),

enriched AS (
    SELECT
        f.sales_order_id,
        f.purpose_item ->> 'purchase_purpose' AS purchase_purpose_id,
        pp.purpose_name
    FROM flattened f
    LEFT JOIN {{ ref('stg_erpnext__purchase_purposes') }} pp
        ON f.purpose_item ->> 'purchase_purpose' = pp.purchase_purpose_id
    WHERE f.purpose_item ->> 'purchase_purpose' IS NOT NULL
)

SELECT
    sales_order_id AS erp_sales_order_id,
    purchase_purpose_id,
    purpose_name
FROM enriched
