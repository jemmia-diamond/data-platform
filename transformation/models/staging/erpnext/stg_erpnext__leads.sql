{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS lead_id,
    
    -- Basic Profile
    lead_name,
    first_name,
    title,
    salutation,
    gender,
    birth_date::date AS birth_date,
    
    -- Contact Information
    email_id AS email,
    COALESCE(phone, mobile_no) AS phone,
    phone AS phone_number,
    mobile_no AS mobile_number,
    
    -- Address & Geography
    address,
    province,
    region,
    country,
    place_of_issuance,
    
    -- Company/B2B Profile
    company,
    annual_revenue::numeric AS annual_revenue,
    no_of_employees,
    
    -- Lead Tracking & Source
    source,
    lead_source_name,
    lead_source_platform,
    request_type,
    pancake_data,
    preferred_product_types,
    
    -- Marketing/Subscription Flags
    blog_subscriber::int::boolean AS is_blog_subscriber,
    unsubscribed::int::boolean AS is_unsubscribed,
    
    -- Lead Status & Qualification
    status,
    lead_stage,
    qualification_status,
    type,
    qualified_by,
    
    -- Needs & Requirements
    budget_lead,
    proposed_budget,
    purpose_lead,
    expected_delivery_date::date AS expected_delivery_date,
    
    -- Ownership & Assignment
    lead_owner,
    is_assigned::int::boolean AS is_assigned,
    
    -- Images
    image,
    
    -- Flags & Configuration
    disabled::int::boolean AS is_disabled,
    docstatus::int AS docstatus,
    naming_series,
    language,
    idx::int AS idx,
    
    -- Timestamps
    lead_received_date::timestamp AS lead_received_date,
    first_reach_at::timestamp AS first_reach_at,
    qualified_lead_date::timestamp AS qualified_lead_date,
    qualified_on::timestamp AS qualified_on,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by,
    
    -- Frappe Internal & Metadata
    _user_tags,
    _assign,
    _comments,
    _liked_by,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'leads') }}
WHERE name NOT IN (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }}
    WHERE deleted_doctype = 'Lead'
      AND (restored IS NULL OR restored = 0)
)
