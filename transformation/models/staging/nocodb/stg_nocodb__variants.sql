{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS variant_id,
    haravan_variant_id::bigint,
    haravan_product_id::bigint,
    barcode,
    sku,
    product_id::bigint,
    price::numeric,
    {{ safe_cast_numeric('final_discount_price') }} AS final_discount_price,
    qty_available::int,
    qty_onhand::int,
    qty_commited::int,
    qty_incoming::int,
    category,
    applique_material,
    fineness,
    material_color,
    size_type,
    {{ safe_cast_numeric('ring_size') }} AS ring_size,
    title,
    {{ safe_cast_numeric('estimated_gold_weight') }} AS estimated_gold_weight,
    design_code,
    design_type,
    design_gender,
    design_source,
    {{ safe_cast_int('design_seq') }} AS design_seq,
    {{ safe_cast_int('design_variant') }} AS design_variant,
    design_year,
    ma_thiet_ke_cu,
    ma_erp,
    haravan_product_type,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'variants') }}
