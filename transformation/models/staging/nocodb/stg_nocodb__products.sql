{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS product_id,
    haravan_product_id::bigint,
    vendor,
    haravan_product_type,
    design_id::bigint,
    published_scope,
    title,
    product_title,
    ecom_title,
    handle,
    template_suffix,
    published,
    price_max::numeric,
    price_min::numeric,
    {{ safe_cast_boolean('auto_create_haravan') }} AS auto_create_haravan,
    {{ safe_cast_numeric('estimated_gold_weight') }} AS estimated_gold_weight,
    {{ safe_cast_boolean('has_360') }} AS has_360,
    design_type,
    design_gender,
    design_source,
    design_year,
    {{ safe_cast_int('design_seq') }} AS design_seq,
    {{ safe_cast_int('design_variant') }} AS design_variant,
    design_code,
    ma_thiet_ke_cu,
    ma_erp,
    tag,
    sold_before_2025::int,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ dedup_nocodb('products', 'COALESCE(haravan_product_id::text, design_code)') }}
