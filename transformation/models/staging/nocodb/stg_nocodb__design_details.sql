{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS detail_id,
    {{ safe_cast_numeric('gold_weight') }} AS gold_weight,
    {{ safe_cast_numeric('labour_cost') }} AS labour_cost,
    melee_total_price::numeric,
    design_melee_details::bigint,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'design_details') }}
