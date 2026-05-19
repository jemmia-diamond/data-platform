{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- 1. Identity
    name as sales_person_id,
    sales_person_name,
    employee as employee_id,
    employee_email,
    
    -- 2. Hierarchy & Structure
    parent_sales_person,
    is_group::integer::boolean as is_group,
    lft as tree_left,
    rgt as tree_right,
    
    -- 3. Attributes
    enabled::integer::boolean as is_enabled,
    department,
    sales_region,
    
    -- 4. Financial Metrics
    CASE 
        WHEN commission_rate ~ '^[0-9]+(\.[0-9]+)?$' THEN commission_rate::numeric
        ELSE 0.0
    END AS commission_rate,
    
    -- 5. System Fields & JSON Data
    assigned_lead::integer as assigned_lead_count,
    targets::jsonb as targets,
    docstatus::integer as docstatus,
    idx::integer as idx,
    
    -- 6. Audit Timestamps
    creation as created_at,
    modified as updated_at,
    _db_updated_at

FROM {{ source('erpnext', 'sales_persons') }}
WHERE name NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Sales Person'
      AND (restored IS NULL OR restored = 0)
)
