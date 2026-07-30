{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS opportunity_id,

    -- Party / Contact
    party_name,
    customer_name,
    contact_person,
    contact_display,
    contact_mobile,
    phone,
    company,

    -- Opportunity Details
    title,
    opportunity_from,
    opportunity_type,
    opportunity_owner,
    source,
    status,
    sales_stage,
    probability,

    -- Financials
    opportunity_amount,
    base_opportunity_amount,
    annual_revenue,
    total,
    base_total,
    conversion_rate,
    currency,

    -- Needs & Requirements
    budget_lead,
    purpose_lead,
    no_of_employees,
    order_lost_reason,

    -- Address & Geography
    country,
    province,
    region,

    -- Dates
    opportunity_date::timestamp AS opportunity_date,
    expected_delivery_date::date AS expected_delivery_date,
    transaction_date::timestamp AS transaction_date,

    -- Flags & Configuration
    docstatus::int AS docstatus,
    naming_series,
    language,
    idx::int AS idx,

    -- Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by

FROM {{ source('erpnext', 'opportunities') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Opportunity'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
)
