{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS design_id,
    code AS design_code_legacy,
    erp_code,
    backup_code,
    design_type,
    gender,
    {{ safe_cast_int('design_year') }} AS design_year,
    {{ safe_cast_int('design_seq') }} AS design_seq,
    usage_status,
    shape_of_main_stone,
    product_line,
    source,
    {{ safe_cast_int('variant_number') }} AS variant_number,
    {{ safe_cast_numeric('gold_weight') }} AS gold_weight,
    main_stone,
    {{ safe_cast_int('stone_quantity') }} AS stone_quantity,
    {{ safe_cast_numeric('stone_weight') }} AS stone_weight,
    diamond_holder,
    design_code,
    new_code,
    design_status,
    published_scope,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'designs') }}
