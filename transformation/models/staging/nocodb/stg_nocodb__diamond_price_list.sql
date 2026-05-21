{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS price_id,
    {{ safe_cast_numeric('size') }} AS size,
    color,
    clarity,
    title,
    carat,
    price::numeric,
    sale_off_price::numeric,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'diamond_price_list') }}
