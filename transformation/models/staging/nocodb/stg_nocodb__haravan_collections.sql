{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS haravan_collection_id,
    collection_type,
    title,
    products_count::int,
    haravan_id::bigint,
    {{ safe_cast_boolean('auto_create') }} AS auto_create,
    -- handle,
    {{ safe_cast_boolean('is_excluded') }} AS is_excluded,
    {{ safe_cast_boolean('is_exclusive') }} AS is_exclusive,
    discount_type,
    {{ safe_cast_numeric('discount_value') }} AS discount_value,
    start_date,
    end_date,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'haravan_collections') }}
