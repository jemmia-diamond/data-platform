{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    variant_id,
    qty_available,
    location_id                                                          AS loc_id
FROM {{ ref('stg_haravan__inventory_locations') }}
