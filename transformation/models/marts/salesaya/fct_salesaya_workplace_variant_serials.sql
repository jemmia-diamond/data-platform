{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    serial_id                                                            AS id,
    variant_id,
    serial_number,
    stock_at,
    storage_size_1,
    storage_size_2,
    order_reference
FROM {{ ref('stg_nocodb__variant_serials') }}
