{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_address as (
    select * from {{ ref('stg_erpnext__addresses') }} -- Giả định tên file staging của bạn
),

processed_addresses as (
    select
        -- 1. Identity & Deterministic Keys
        address_id,
        address_name,
        haravan_id as haravan_address_id,

        -- 2. Address Attributes
        address_type, -- Billing, Shipping, Office...
        address_line1,
        address_line2,
        
        trim(
            coalesce(address_line1, '') || ' ' || 
            coalesce(address_line2, '')
        ) as street_address,
        
        -- 3.  (Geography Layer)
        ward,
        district,
        province,
        country,
        
        -- 4. Contact Info attached to Address
        email,
        phone,

        -- 5. Status & Flags
        is_primary_address,
        is_shipping_address,
        is_your_company_address,
        is_disabled,
        
        -- 6. System & Audit Fields
        docstatus,
        idx,
        created_at,
        updated_at,
        _db_updated_at

    from staging_address
)

select * from processed_addresses