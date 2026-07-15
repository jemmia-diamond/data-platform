{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    variant_id                                                           AS id,
    product_id,
    haravan_variant_id,
    sku,
    ring_size,
    fineness,
    material_color,
    final_discount_price
FROM {{ ref('stg_nocodb__variants') }}
