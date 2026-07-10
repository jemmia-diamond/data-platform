{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS serial_id,
    serial_number,
    printing_batch,
    encode_barcode,
    final_encoded_barcode,
    {{ safe_cast_numeric('gold_weight') }} AS gold_weight,
    {{ safe_cast_numeric('diamond_weight') }} AS diamond_weight,
    quantity::int,
    supplier,
    cogs::numeric,
    price::numeric,
    barcode,
    sku,
    variant_id::bigint,
    order_id::bigint,
    stock_id,
    order_on,
    order_reference,
    product_name,
    displayed_title,
    fulfillment_status_value,
    {{ safe_cast_timestamp('last_rfid_scan_time') }} AS last_rfid_scan_time,
    arrival_date,
    {{ safe_cast_numeric('actual_gold_price') }} AS actual_gold_price,
    {{ safe_cast_numeric('actual_melee_price') }} AS actual_melee_price,
    {{ safe_cast_numeric('actual_labor_cost') }} AS actual_labor_cost,
    {{ safe_cast_boolean('is_have_invoice') }} AS is_have_invoice,
    supplier_invoice,
    address_invoice,
    policy,
    haravan_product_type,
    design_code,
    ma_thiet_ke_cu,
    ma_erp,
    stock_at,
    {#
    {{ safe_cast_numeric('storage_size_1') }} AS storage_size_1,
    {{ safe_cast_numeric('storage_size_2') }} AS storage_size_2,
    #}
    {{ safe_cast_timestamp('database_created_at') }} AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'variant_serials') }}
