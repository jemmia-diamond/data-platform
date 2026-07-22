{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS diamond_id,
    barcode,
    report_lab,
    report_no,
    price::numeric,
    cogs::numeric,
    product_group,
    shape,
    cut,
    color,
    clarity,
    fluorescence,
    edge_size_1::numeric,
    edge_size_2::numeric,
    carat::numeric,
    original_code,
    sku,
    product_name,
    product_id as haravan_product_id,
    variant_id as haravan_variant_id,
    qty_onhand::int,
    qty_available::int,
    qty_commited::int,
    qty_incoming::int,
    vendor,
    published_scope,
    image_urls,
    {# 
    {{ safe_cast_date('expected_arrival_date') }} AS expected_arrival_date,
    #}
    {{ safe_cast_boolean('is_incoming') }} AS is_incoming,
    {{ safe_cast_boolean('is_have_invoice') }} AS is_have_invoice,
    country_of_origin,
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ dedup_nocodb('diamonds', 'barcode') }}
