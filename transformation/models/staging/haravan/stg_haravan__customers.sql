{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS customer_id,
    first_name,
    last_name,
    email,
    phone,
    gender::int AS gender,
    birthday::timestamp AS birthday,
    
    -- Status & Preferences
    state,
    (accepts_marketing)::boolean AS accepts_marketing,
    (verified_email)::boolean AS verified_email,
    tags,
    note,
    
    -- Lifetime Value Metrics
    (orders_count)::int AS orders_count,
    (total_spent)::numeric AS total_spent,
    (total_paid)::numeric AS total_paid,
    
    -- Last Order Info
    (last_order_id)::bigint AS last_order_id,
    last_order_name,
    last_order_date::timestamp AS last_order_date,
    
    -- Full Default Address Info
    default_address, -- Kept raw as JSONB backup
    default_address->>'name' AS default_address_name,
    default_address->>'phone' AS default_address_phone,
    default_address->>'address1' AS default_address_line1,
    default_address->>'address2' AS default_address_line2,
    default_address->>'ward' AS default_ward,
    default_address->>'ward_code' AS default_ward_code,
    default_address->>'district' AS default_district,
    default_address->>'district_code' AS default_district_code,
    default_address->>'province' AS default_province,
    default_address->>'province_code' AS default_province_code,
    default_address->>'city' AS default_city,
    default_address->>'country' AS default_country,
    default_address->>'country_code' AS default_country_code,
    default_address->>'zip' AS default_zip_code,
    default_address->>'company' AS default_company,
    
    -- Timestamps
    created_at::timestamp AS created_at,
    updated_at::timestamp AS updated_at,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'customers') }}
