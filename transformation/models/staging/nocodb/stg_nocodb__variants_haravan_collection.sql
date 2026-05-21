{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    variants_id::bigint AS variant_id,
    haravan_collections_id::bigint AS haravan_collection_id,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'variants_haravan_collection') }}
