{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_opportunity_date ON {{ this }} USING brin (opportunity_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_lead_id ON {{ this }} (lead_id)",
      "CREATE INDEX IF NOT EXISTS idx_fso_sales_person_key ON {{ this }} (sales_person_key)",
    ]
) }}

WITH opportunities AS (
    SELECT * FROM {{ ref('int_crm__opportunities') }}
),

leads AS (
    SELECT lead_id, email, pancake_customer_id
    FROM {{ ref('int_crm__leads') }}
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
),

contacts AS (
    SELECT pancake_customer_id, ad_ids
    FROM {{ ref('int_crm__contacts') }}
)

SELECT
    o.opportunity_id,
    o.party_name AS lead_id,

    sp.sales_person_id AS sales_person_key,
    sp.sales_person_name,
    COALESCE(sp.region_name, r.region_name) AS region,
    sp.region_name AS sales_region,
    r.region_name AS opportunity_region,

    {{ mask_email('l.email') }} AS email,
    {{ mask_phone('o.phone') }} AS phone,
    {{ mask_phone('o.contact_mobile') }} AS contact_mobile,
    o.contact_person,
    o.contact_display,
    o.customer_name,
    c.ad_ids,

    o.title,
    o.company,
    o.opportunity_from,
    o.opportunity_type,
    o.opportunity_owner,
    o.source,
    o.status,
    o.sales_stage,
    o.probability,

    o.opportunity_amount,
    o.base_opportunity_amount,
    o.annual_revenue,
    o.total,
    o.base_total,
    o.conversion_rate,
    o.currency,

    o.order_lost_reason,

    o.budget_lead,
    b.budget_label,
    b.budget_from,
    b.budget_to,
    o.purpose_lead,
    d.demand_label,

    o.no_of_employees,
    o.province,
    o.country,

    o.opportunity_date,
    o.expected_delivery_date,
    o.transaction_date,

    o.created_at,
    o.updated_at,
    o.owner

FROM opportunities o
LEFT JOIN leads l
    ON l.lead_id = o.party_name
LEFT JOIN sales_persons sp
    ON o.opportunity_owner = sp.employee_email
LEFT JOIN budgets b
    ON o.budget_lead = b.lead_budget_id
LEFT JOIN demands d
    ON o.purpose_lead = d.lead_demand_id
LEFT JOIN regions r
    ON o.region = r.region_id
LEFT JOIN contacts c
    ON c.pancake_customer_id = l.pancake_customer_id
