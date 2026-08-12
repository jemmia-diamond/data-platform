{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id,
    name,
    platform,
    is_activated,
    connected,
    shop_id,
    inserted_at::timestamptz AS inserted_at,
    _db_updated_at::timestamptz AS _db_updated_at

FROM {{ source('pancake', 'page') }}
