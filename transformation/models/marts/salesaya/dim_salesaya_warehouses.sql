{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya warehouse feed — Haravan location attributes presented as a warehouse dimension.
-- Grain: 1 row per Haravan location.
SELECT
    location_id     AS warehouse_id,
    location_name   AS warehouse_name,
    location_type   AS warehouse_type,
    is_primary      AS is_primary_warehouse,
    status          AS warehouse_status
FROM {{ ref('int_inventory__locations') }}
