{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH stock AS (
    SELECT * FROM {{ ref('int_inventory__stock_by_location') }}
)

SELECT
    variant_id,
    SUM(qty_available)                                                              AS total_qty_available,
    MAX(location_id)                                                                AS primary_location_id,
    jsonb_object_agg(location_name, qty_available) FILTER (WHERE qty_available > 0) AS stock_by_location_name,
    json_agg(json_build_object(
        'id', location_id,
        'name', location_name,
        'qty_available', qty_available
    )) FILTER (WHERE qty_available > 0)                                            AS warehouses
FROM stock
GROUP BY variant_id
