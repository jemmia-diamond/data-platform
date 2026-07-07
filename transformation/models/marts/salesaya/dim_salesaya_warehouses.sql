{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH haravan_locations AS (
    SELECT * FROM {{ ref('stg_haravan__locations') }}
)

SELECT
    location_id     AS warehouse_id,
    name            AS warehouse_name,
    location_type   AS warehouse_type,
    is_primary      AS is_primary_warehouse,
    status          AS warehouse_status
FROM haravan_locations
