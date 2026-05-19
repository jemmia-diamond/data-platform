{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS lead_demand_id,
    
    -- Source Information
    demand_label,
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

FROM {{ source('erpnext', 'lead_demands') }}
WHERE name NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Lead Demand'
    AND (restored IS NULL OR restored = 0)
)