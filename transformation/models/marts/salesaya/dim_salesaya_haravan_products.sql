{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    product_id                                                           AS id,
    title,
    product_type,
    images,
    published_scope
FROM {{ ref('stg_haravan__products') }}
