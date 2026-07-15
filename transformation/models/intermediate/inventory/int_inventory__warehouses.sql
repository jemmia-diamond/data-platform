{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH locations AS (
    SELECT * FROM {{ ref('stg_haravan__locations') }}
)

SELECT
    location_id,
    name,
    location_type,
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
    is_primary,
    is_unavailable_quantity,
    type,
    status,
    created_at,
    updated_at
FROM locations
