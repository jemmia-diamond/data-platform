{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    variant_id                                                           AS id,
    product_id,
    price,
    variant_title                                                        AS title,
    barcode,
    sku
FROM {{ ref('stg_haravan__product_variants') }}
