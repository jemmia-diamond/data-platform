{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS temp_product_id,
    haravan_product_id::bigint,
    haravan_variant_id::bigint,
    customer_name,
    customer_phone,
    variant_title,
    code,
    price::numeric,
    product_information,
    design_id::bigint,
    category,
    applique_material,
    material_color,
    size_type,
    {{ safe_cast_numeric('ring_size') }} AS ring_size,
    fineness,
    design_code,
    ticket_type,
    product_group,
    gia_report_no,
    request_code,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'temporary_products') }}
