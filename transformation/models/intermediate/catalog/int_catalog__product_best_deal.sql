{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH product_collection_links AS (
    SELECT * FROM {{ ref('stg_nocodb__products_haravan_collection') }}
),

haravan_collections AS (
    SELECT * FROM {{ ref('int_catalog__haravan_collections') }}
)

SELECT DISTINCT ON (product_collection_links.product_id)
    product_collection_links.product_id,
    haravan_collections.discount_type,
    haravan_collections.discount_value
FROM product_collection_links
JOIN haravan_collections
    ON haravan_collections.haravan_collection_id = product_collection_links.haravan_collection_id
ORDER BY product_collection_links.product_id, haravan_collections.discount_value DESC NULLS LAST
