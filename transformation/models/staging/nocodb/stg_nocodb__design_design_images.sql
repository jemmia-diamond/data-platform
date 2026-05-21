{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS image_id,
    design_id::bigint,
    material_color,
    retouch,
    {{ safe_cast_boolean('tick_sync_to_haravan') }} AS tick_sync_to_haravan,
    note,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'design_design_images') }}
