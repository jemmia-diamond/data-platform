{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS address_id,
    
    -- Address Core Info
    address_name,
    address_type,
    address_line1,
    address_line2,
    ward,
    district,
    province,
    country,
    
    -- Contact Details
    email_id AS email,
    phone,
    
    -- External System IDs
    haravan_id,
    
    -- Address Flags
    is_primary_address::int::boolean AS is_primary_address,
    is_shipping_address::int::boolean AS is_shipping_address,
    is_your_company_address::int::boolean AS is_your_company_address,
    disabled::int::boolean AS is_disabled,
    
    -- Status & Auditing
    docstatus::int AS docstatus,
    idx::int AS idx,
    
    -- Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'address') }}
WHERE name NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Address'
      AND (restored IS NULL OR restored = 0)
)
