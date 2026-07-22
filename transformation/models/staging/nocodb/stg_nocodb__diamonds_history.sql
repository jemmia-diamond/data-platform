{{
    config(
        materialized='view',
        schema='staging'
    )
}}

SELECT
    id::bigint AS diamond_history_id,
    {{ safe_cast_date('date') }} AS history_date,
    stage,
    status,
    errors,
    error_level,
    note,
    attachment,
    buyback_tradein_order,
    buyback_tradein_status,
    purchase_statement,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'diamonds_history') }}
