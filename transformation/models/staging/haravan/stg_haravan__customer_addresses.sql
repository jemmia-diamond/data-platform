{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint AS customer_id,
        jsonb_array_elements(addresses) AS address
    FROM {{ source('haravan', 'customers') }}
    WHERE addresses IS NOT NULL AND jsonb_typeof(addresses) = 'array'
)

SELECT
    (address->>'id')::bigint AS address_id,
    customer_id,
    address->>'name' AS full_name,
    address->>'first_name' AS first_name,
    address->>'last_name' AS last_name,
    address->>'phone' AS phone,
    
    -- Location details
    address->>'address1' AS address1,
    address->>'address2' AS address2,
    address->>'ward' AS ward,
    address->>'ward_code' AS ward_code,
    address->>'district' AS district,
    address->>'district_code' AS district_code,
    address->>'province' AS province,
    address->>'province_code' AS province_code,
    address->>'city' AS city,
    address->>'country' AS country,
    address->>'country_code' AS country_code,
    address->>'zip' AS zip_code,
    address->>'company' AS company,
    
    (address->>'default')::boolean AS is_default_address

FROM unnested
