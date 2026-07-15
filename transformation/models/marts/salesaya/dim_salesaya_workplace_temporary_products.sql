{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    gia_report_no,
    haravan_variant_id,
    haravan_product_id
FROM {{ ref('stg_nocodb__temporary_products') }}
