{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    products_id::bigint AS product_id,
    haravan_collections_id::bigint AS haravan_collection_id,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'products_haravan_collection') }}
