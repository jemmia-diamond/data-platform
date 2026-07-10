{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    diamonds_id::bigint AS diamond_id,
    variant_serials_id::bigint AS serial_id,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'variant_serials_diamonds') }}
