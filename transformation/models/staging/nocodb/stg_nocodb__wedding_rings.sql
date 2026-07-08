{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS wedding_ring_id,
    description,
    ecom_title,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'wedding_rings') }}
