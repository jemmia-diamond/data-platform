{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    diamond_id::bigint,
    haravan_collection_id::bigint,
    position::int,
    {{ safe_cast_boolean('is_primary') }} AS is_primary,
    {{ safe_cast_timestamp('created_at') }} AS created_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'diamonds_haravan_collection') }}
