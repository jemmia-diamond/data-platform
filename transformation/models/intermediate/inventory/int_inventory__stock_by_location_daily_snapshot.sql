{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    il.snapshot_date as report_date,
    il.loc_id as location_id,
    loc.name AS location_name,
    loc.is_primary AS is_primary_location,
    il.variant_id,
    il.product_id,
    p.title AS product_title,
    p.product_type,
    pv.sku,
    pv.barcode,
    pv.variant_title,
    pv.price AS variant_price,
    il.qty_onhand,
    il.qty_commited,
    il.qty_incoming,
    il.qty_available,
    il._db_updated_at

FROM {{ ref('stg_haravan__inventory_locations_balance_daily_snapshot') }} il
LEFT JOIN {{ ref('stg_haravan__locations') }} loc
    ON il.loc_id = loc.location_id
LEFT JOIN {{ ref('stg_haravan__product_variants') }} pv
    ON il.variant_id = pv.variant_id
LEFT JOIN {{ ref('stg_haravan__products') }} p
    ON pv.product_id = p.product_id
