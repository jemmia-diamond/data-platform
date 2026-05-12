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
    
    -- Pancake Data Extraction
    pancake_data ->> 'platform' AS pancake_platform,
    pancake_data ->> 'page_name' AS pancake_page_name,
    pancake_data ->> 'page_id' AS pancake_page_id,
    pancake_data ->> 'customer_id' AS pancake_customer_id,
    pancake_data ->> 'conversation_id' AS pancake_conversation_id,
    
    -- Preferred Products Summary (Optional: for quick view)
    preferred_product_types,
    
    -- Qualification & Status
    status,
    lead_stage,
    qualification_status,
    qualified_by,
    
    -- Temporal (Raw)
    lead_received_date,
    first_reach_at AS lead_entry_at, -- Using first_reach_at as the primary entry point per user request
    qualified_on AS converted_at,
    preferred_product_types,
    
    -- Business Metrics (Calculated)
    CASE WHEN qualification_status = 'Qualified' THEN 1 ELSE 0 END AS is_converted,
    
    CASE 
        WHEN qualification_status = 'Qualified' AND qualified_on IS NOT NULL AND first_reach_at IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (qualified_on - first_reach_at)) / 3600 
        ELSE NULL 
    END AS time_to_convert_hours,
    
    EXTRACT(DAY FROM (COALESCE(CASE WHEN qualification_status = 'Qualified' THEN qualified_on END, CURRENT_TIMESTAMP) - first_reach_at)) AS current_lead_age_days,
    

    -- Ownership
    lead_owner,
    is_assigned,
    
    -- Metadata
    _db_updated_at

FROM leads
