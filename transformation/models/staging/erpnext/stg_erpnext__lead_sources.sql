{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS lead_source_id,
    
    -- Source Information
    source_name,
    details,
    pancake_platform,
    pancake_page_id,
    
    -- Audit & Metadata
    docstatus::int AS docstatus,
    idx::int AS idx,
    owner,
    modified_by,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'lead_sources') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Lead Source'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
      AND dd.data::jsonb->>'source_name' = source_name
)