{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    -- Identity
    opportunity_id,
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

    -- Geography
    country,
    province,
    region,

    -- Dates
    opportunity_date,
    expected_delivery_date,
    transaction_date,

    -- Metadata
    created_at,
    updated_at,
    owner,
    modified_by

FROM {{ ref('stg_erpnext__opportunities') }}
WHERE
    {{ exclude_dev_test_accounts('opportunity_owner') }}
