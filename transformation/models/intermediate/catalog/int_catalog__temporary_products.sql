{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Temporary product reference (GIA-tracked one-off products) — source of truth for
-- temporary product identity, Haravan links and GIA report number.
-- Grain: 1 row per temporary product.
SELECT
    temp_product_id,
    haravan_product_id,
    haravan_variant_id,
    gia_report_no,
    customer_name,
    customer_phone,
    variant_title,
    code,
    price,
    design_id,
    category,
    applique_material,
    material_color,
    size_type,
    ring_size,
    fineness,
    design_code,
    ticket_type,
    product_group,
    request_code,
    created_at,
    _db_updated_at
FROM {{ ref('stg_nocodb__temporary_products') }}
