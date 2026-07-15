{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    diamond_id                                                           AS id,
    haravan_variant_id                                                   AS variant_id,
    image_urls,
    barcode,
    haravan_product_id                                                   AS product_id,
    edge_size_1,
    edge_size_2,
    color,
    clarity,
    fluorescence,
    shape,
    cut,
    carat,
    price,
    is_incoming,
    report_no
    -- expected_arrival_date is omitted: the NocoDB diamonds table has no such field.
FROM {{ ref('stg_nocodb__diamonds') }}
