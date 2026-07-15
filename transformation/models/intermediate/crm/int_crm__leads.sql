{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH leads AS (
    SELECT * FROM {{ ref('stg_erpnext__leads') }}
)

SELECT
    -- Identity
    lead_id,
    lead_name,
    first_name,
    gender,
    birth_date,
    
    -- Contact
    email,
    phone,
    
    -- Geography
    province,
    region,
    country,
    
    -- Marketing & Source
    source,
    lead_source_name,
    lead_source_platform,
    
    -- Pancake Data Extraction (no need to cast to jsonb again - already JSONB in staging)
    pancake_data::jsonb ->> 'platform' AS pancake_platform,
    pancake_data::jsonb ->> 'page_name' AS pancake_page_name,
    pancake_data::jsonb ->> 'page_id' AS pancake_page_id,
    pancake_data::jsonb ->> 'customer_id' AS pancake_customer_id,
    pancake_data::jsonb ->> 'conversation_id' AS pancake_conversation_id,
    
    -- Qualification & Status
    status,
    lead_stage,
    qualification_status,
    qualified_by,
    
    -- Temporal (Raw)
    first_reach_at AS lead_entry_at, -- Using first_reach_at as the primary entry point per user request
    qualified_on AS converted_at,
    
    -- Business Metrics (Calculated)
    (qualification_status = 'Qualified') AS is_converted,
    
    CASE 
        WHEN qualification_status = 'Qualified' AND qualified_on IS NOT NULL AND first_reach_at IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (qualified_on - first_reach_at)) / 3600 
        ELSE NULL 
    END AS time_to_convert_hours,
    
    EXTRACT(DAY FROM (COALESCE(CASE WHEN qualification_status = 'Qualified' THEN qualified_on END, CURRENT_TIMESTAMP) - first_reach_at)) AS current_lead_age_days,
    

    -- Ownership
    lead_owner,
    is_assigned,
    _assign ->> 0 AS assigned_to,
    
    -- References
    budget_lead,
    proposed_budget,
    purpose_lead,
    preferred_product_types,
    
    -- Metadata
    _db_updated_at

FROM leads
