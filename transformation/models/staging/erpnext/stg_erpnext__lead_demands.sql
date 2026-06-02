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
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Lead Demand'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
      AND dd.data::jsonb->>'demand_label' = demand_label
)