{{
    config(
        materialized='view',
        schema='staging'
    )
}}

SELECT
    diamonds_id::bigint AS diamond_id,
    diamonds_history_id::bigint AS diamond_history_id,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'diamonds_history_diamonds') }}
