{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    product_id                                                           AS products_id,
    haravan_collection_id                                                AS haravan_collections_id
FROM {{ ref('stg_nocodb__products_haravan_collection') }}
