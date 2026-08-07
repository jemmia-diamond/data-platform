{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                     AS design_set_id,
    design_id::bigint                                              AS design_id,
    set_id::bigint                                                 AS set_id,
    {{ safe_cast_timestamp('database_created_at') }}               AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }}               AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'design_set') }}
