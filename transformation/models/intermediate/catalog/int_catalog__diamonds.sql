{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Diamond source of truth — one row per loose diamond, sourced from NocoDB diamonds.
-- Carries diamond identity, physical attributes, list price, GIA report, imagery and own stock.
-- Grain: 1 row per diamond.
SELECT
    diamond_id,
    barcode,
    haravan_product_id AS product_id,
    haravan_variant_id AS variant_id,
    edge_size_1,
    edge_size_2,
    color,
    clarity,
    fluorescence,
    shape,
    cut,
    carat,
    is_incoming,
    price AS base_price,
    report_no,
    report_lab,
    image_urls,
    sku,
    product_name,
    original_code,
    product_group,
    vendor,
    cogs,
    country_of_origin,
    is_have_invoice,
    published_scope,
    qty_onhand,
    qty_available,
    qty_commited,
    qty_incoming,
    created_at,
    updated_at,
    _db_updated_at
FROM {{ ref('stg_nocodb__diamonds') }}
