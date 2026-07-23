{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Haravan location dimension (warehouse reference) — source of truth for location/warehouse attributes.
-- Grain: 1 row per Haravan location.
SELECT
    location_id,
    name AS location_name,
    location_type,
    is_primary,
    is_unavailable_quantity,
    type,
    status,
    email,
    address1,
    city,
    zip,
    province,
    province_code,
    district,
    district_code,
    ward,
    ward_code,
    country,
    phone,
    created_at,
    updated_at,
    _db_updated_at
FROM {{ ref('stg_haravan__locations') }}
