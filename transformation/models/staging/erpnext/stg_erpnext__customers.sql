{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS customer_id,
    
    -- Basic Profile
    customer_name,
    first_name,
    last_name,
    person_name,
    salutation,
    customer_type,
    gender,
    birth_date::date AS birth_date,
    
    -- Contact Information
    email_id AS email,
    COALESCE(phone, mobile_no) AS phone,
    phone AS phone_number,
    mobile_no AS mobile_number,
    
    -- Linked Primary Records
    customer_primary_contact,
    primary_contact,
    customer_primary_address,
    primary_address,
    
    -- External System IDs
    haravan_id,
    bizfly_customer_number,
    
    -- Identity & Documents
    personal_document_type,
    personal_id,
    date_of_issuance::date AS date_of_issuance,
    place_of_issuance,
    passport_id,
    date_of_passport_issuance::date AS date_of_passport_issuance,
    passport_expiry_date::date AS passport_expiry_date,
    place_of_passport_issuance,
    customer_identity_image,
    front_image,
    back_image,
    
    -- Tax & VAT Info
    personal_tax_id,
    vat_name,
    vat_address,
    vat_email,
    
    -- Lead & Opportunity Info
    lead_name,
    first_source,
    customer_journey,
    opportunity_name,
    partner_role,
    
    -- Ranking & Scoring
    customer_rank,
    rank,
    rank_score_12m::numeric AS rank_score_12m,
    rank_updated_at::date AS rank_updated_at,
    
    -- Revenue & Sales Metrics
    actual_cumulative_revenue::numeric AS actual_cumulative_revenue,
    buyback_revenue::numeric AS buyback_revenue,
    cumulative_revenue::numeric AS cumulative_revenue,
    purchase_amount_last_12_months::numeric AS purchase_amount_last_12_months,
    referral_cumulative_revenue::numeric AS referral_cumulative_revenue,
    referrals_revenue::numeric AS referrals_revenue,
    total_cumulative_revenue::numeric AS total_cumulative_revenue,
    true_cumulative_revenue::numeric AS true_cumulative_revenue,
    
    -- Loyalty, Cashback & Points
    available_point_amount::numeric AS available_point_amount,
    cashback::numeric AS cashback,
    pending_cashback::numeric AS pending_cashback,
    total_referral_point::numeric AS total_referral_point,
    withdraw_cash_amount::numeric AS withdraw_cash_amount,
    withdraw_cash_amount_pending::numeric AS withdraw_cash_amount_pending,
    withdraw_cashback::numeric AS withdraw_cashback,
    withdraw_point::numeric AS withdraw_point,
    
    -- Settings & Financial Config
    default_commission_rate::numeric AS default_commission_rate,
    invoice_type,
    language,
    naming_series,
    
    -- Flags
    disabled::int::boolean AS is_disabled,
    is_frozen::int::boolean AS is_frozen,
    is_internal_customer::int::boolean AS is_internal_customer,
    dn_required::int::boolean AS dn_required,
    so_required::int::boolean AS so_required,
    
    -- Status & Audit
    docstatus::int AS docstatus,
    idx::int AS idx,
    owner,
    modified_by,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    
    -- Frappe Internal
    _comments,
    _assign,
    
    -- DLT Metadata
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'customers') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Customer'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
      AND dd.data::jsonb->>'customer_name' = customer_name
)
