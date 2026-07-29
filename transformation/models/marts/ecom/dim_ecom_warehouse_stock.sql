{{ config(
    schema='marts_ecom'
) }}

-- Ecom warehouse stock — serves the availability API (GET products/:id/availability). One row per
-- (variant, location) with available stock, keyed by product_id so the API can filter
-- `WHERE product_id = ?`. Materialized as a VIEW so it stays fresh with the raw inventory sync
-- (the availability API needs near-real-time stock). Mirrors the legacy availability raw query.
SELECT
    sl.product_id,
    sl.variant_id,
    sl.location_id                                                     AS store_id,
    sl.location_name                                                   AS store_name,
    SUM(sl.qty_available)                                              AS available_quantity
FROM {{ ref('int_inventory__stock_by_location') }} sl
GROUP BY sl.product_id, sl.variant_id, sl.location_id, sl.location_name
HAVING SUM(sl.qty_available) > 0
