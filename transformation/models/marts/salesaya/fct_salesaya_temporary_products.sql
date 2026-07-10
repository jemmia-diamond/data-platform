{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH temporary_products AS (
    SELECT * FROM {{ ref('stg_nocodb__temporary_products') }}
),

sold_order_lines AS (
    SELECT * FROM {{ ref('stg_haravan__order_lines') }}
)

SELECT
    temporary_products.gia_report_no AS gia_report_number
FROM temporary_products
JOIN sold_order_lines
    ON sold_order_lines.variant_id = temporary_products.haravan_variant_id
   AND sold_order_lines.product_id = temporary_products.haravan_product_id
WHERE temporary_products.gia_report_no IS NOT NULL
