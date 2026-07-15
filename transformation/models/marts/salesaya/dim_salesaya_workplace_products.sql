{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    product_id                                                           AS id,
    design_id,
    haravan_product_id
FROM {{ ref('stg_nocodb__products') }}
