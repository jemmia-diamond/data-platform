{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH erpnext_customers AS (
    SELECT * FROM {{ ref('stg_erpnext__customers') }}
),

haravan_customers AS (
    SELECT * FROM {{ ref('stg_haravan__customers') }}
),

lead_sources AS (
    SELECT * FROM {{ ref('stg_erpnext__lead_sources') }}
)

SELECT
    -- Identity Keys
    e.customer_id AS erp_customer_id,
    h.customer_id AS haravan_customer_id,

    -- Basic Profile (Prioritize Haravan for marketing details)
    COALESCE(h.first_name || ' ' || h.last_name, e.customer_name) AS full_name,
    COALESCE(h.email, e.email) AS email,
    COALESCE(h.phone, e.phone) AS phone,
    -- Normalized Gender (Mapping Haravan 1:Male, 2:Female or similar to ERPNext strings)
    COALESCE(
        CASE 
            WHEN h.gender = 1 THEN 'Male'
            WHEN h.gender = 2 THEN 'Female'
            WHEN h.gender = 0 THEN 'Unknown'
            ELSE NULL 
        END, 
        e.gender
    ) AS gender,
    COALESCE(h.birthday::date, e.birth_date) AS birth_date,

    -- Address Info
    h.default_address_name,
    h.default_address_phone,
    h.default_address_line1,
    h.default_ward,
    h.default_ward_code,
    h.default_district,
    h.default_district_code,
    h.default_province,
    h.default_province_code,
    h.default_country, 
    h.default_country_code,
    e.customer_primary_contact,
    
    -- Legal & ID Info (Exclusive to ERPNext)
    e.personal_document_type,
    e.personal_id,
    e.date_of_issuance,
    e.place_of_issuance,
    e.passport_id,
    e.date_of_passport_issuance,
    e.passport_expiry_date,
    e.place_of_passport_issuance,

    -- CRM & Marketing Context
    h.accepts_marketing,
    h.tags AS haravan_tags,
    h.note AS haravan_notes,

    e.customer_rank,
    e.rank,
    e.customer_journey,
    e.lead_name,
    
    -- Lead Source Mapping (Mapping first_source to lead_sources dimension)
    e.first_source AS lead_source_id,
    ls.source_name AS lead_source_name,
    ls.pancake_platform,

    -- Timestamps
    e.created_at AS erp_created_at,
    h.created_at AS haravan_created_at,
    e.updated_at AS erp_updated_at,
    h.updated_at AS haravan_updated_at


FROM erpnext_customers e
FULL OUTER JOIN haravan_customers h 
    ON e.haravan_id = h.customer_id::text
LEFT JOIN lead_sources ls ON e.first_source = ls.lead_source_id
