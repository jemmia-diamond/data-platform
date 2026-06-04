{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsl_lead_entry_at ON {{ this }} USING brin (lead_entry_at)",
      "CREATE INDEX IF NOT EXISTS idx_fsl_sales_person_key ON {{ this }} (sales_person_key)",
      "CREATE INDEX IF NOT EXISTS idx_fsl_lead_source_name ON {{ this }} (lead_source_name)",
    ]
) }}

WITH leads AS (
    SELECT * FROM {{ ref('int_crm__leads') }}
),

sales_persons AS (
    SELECT sales_person_id, sales_person_name, region_name, employee_email
    FROM {{ ref('int_sales__sales_persons') }}
),

budgets AS (
    SELECT lead_budget_id, budget_label, budget_from, budget_to
    FROM {{ ref('int_crm__lead_budgets') }}
),

demands AS (
    SELECT lead_demand_id, demand_label
    FROM {{ ref('int_crm__lead_demands') }}
),

regions AS (
    SELECT region_id, region_name
    FROM {{ ref('int_sales__regions') }}
)

SELECT
    l.lead_id,
    l.lead_name,

    sp.sales_person_id AS sales_person_key,
    sp.sales_person_name,

    COALESCE(sp.region_name, r.region_name) AS region,
    sp.region_name AS sales_region,
    r.region_name AS lead_region,

    l.email,
    l.phone,
    CASE l.gender
        WHEN 'Male' THEN 'Nam'
        WHEN 'Female' THEN 'Nữ'
        ELSE 'Chưa xác định'
    END AS gender,
    l.birth_date,

    l.province,

    l.source,
    l.lead_source_name,
    l.lead_source_platform,

    l.pancake_platform,
    l.pancake_page_name,
    l.pancake_page_id,
    l.pancake_customer_id,
    l.pancake_conversation_id,

    CASE l.status
        WHEN 'Lead' THEN 'Lead'
        WHEN 'Converted' THEN 'Đã chuyển đổi'
        WHEN 'Qualified' THEN 'Đã đạt chất lượng'
        WHEN 'Spam' THEN 'Spam'
        WHEN 'Opportunity' THEN 'Cơ hội'
        WHEN 'Interested' THEN 'Quan tâm'
        WHEN 'Do Not Contact' THEN 'Không liên lạc'
        WHEN 'Contacted' THEN 'Đã liên lạc'
        ELSE l.status
    END AS lead_status,

    l.qualification_status AS qualification_status_raw,

    CASE l.qualification_status
        WHEN 'Qualified' THEN 'Đã đạt chất lượng'
        WHEN 'Unqualified' THEN 'Chưa đạt chất lượng'
        ELSE l.qualification_status
    END AS qualification_status,

    l.lead_entry_at::date AS lead_entry_date,
    l.lead_entry_at,
    l.converted_at::date AS converted_date,
    l.converted_at,
    l.is_converted,

    l.time_to_convert_hours,
    l.current_lead_age_days,

    l.lead_owner,
    l.is_assigned,
    l.assigned_to,

    l.budget_lead,
    b.budget_label,
    b.budget_from,
    b.budget_to,

    l.purpose_lead,
    d.demand_label,

    l.preferred_product_types,

    l._db_updated_at

FROM leads l
LEFT JOIN sales_persons sp
    ON l.assigned_to = sp.employee_email
LEFT JOIN budgets b
    ON l.budget_lead = b.lead_budget_id
LEFT JOIN demands d
    ON l.purpose_lead = d.lead_demand_id
LEFT JOIN regions r
    ON l.region = r.region_id
