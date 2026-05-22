{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                               AS location_id,
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
    is_primary::boolean                                                      AS is_primary,
    is_unavailable_quantity::boolean                                         AS is_unavailable_quantity,
    type,
    status,
    created_at::timestamp                                                    AS created_at,
    updated_at::timestamp                                                    AS updated_at,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'locations') }}
