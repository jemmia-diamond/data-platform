{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Variant-level warehouse stock aggregate — source of truth for "available stock per variant
-- across all warehouses". Builds on int_inventory__stock_by_location (location x variant grain).
-- Grain: 1 row per variant.
WITH agg AS (
    SELECT
        variant_id,
        jsonb_object_agg(location_name, qty_available)
            FILTER (WHERE qty_available > 0) AS stock_locations,
        json_agg(json_build_object(
            'id', location_id,
            'name', location_name,
            'qty_available', qty_available
        )) FILTER (WHERE qty_available > 0) AS warehouses,
        SUM(qty_available) AS total_qty,
        MAX(location_id) AS primary_location_id
    FROM {{ ref('int_inventory__stock_by_location') }}
    GROUP BY variant_id
)

SELECT
    agg.variant_id,
    agg.stock_locations,
    agg.warehouses,
    agg.total_qty,
    agg.primary_location_id,
    loc.location_name AS primary_location_name
FROM agg
LEFT JOIN {{ ref('int_inventory__locations') }} loc
    ON loc.location_id = agg.primary_location_id
