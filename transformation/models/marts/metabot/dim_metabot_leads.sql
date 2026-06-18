{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot lead dimension. Grain: 1 row = 1 lead.
-- Source: int_crm__leads + sales_persons (assigned_to=employee_email) + budgets + demands + regions.
-- Full decouple from marts_sales.fct_sales_leads.

WITH leads AS (
    SELECT * FROM {{ ref('int_crm__leads') }}
),

sales_persons AS (
    SELECT sales_person_id, region_name, employee_email
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

preferred_products AS (
    SELECT
        pp.lead_id,
        STRING_AGG(DISTINCT p.product_type, ', ' ORDER BY p.product_type) AS preferred_products
    FROM {{ ref('int_crm__lead_preferred_products') }} pp
    LEFT JOIN {{ ref('int_crm__lead_products') }} p
        ON pp.product_type = p.lead_product_id
    WHERE pp.product_type IS NOT NULL
    GROUP BY pp.lead_id
)

SELECT
    l.lead_id,
    l.lead_name,

    sp.sales_person_id,
    COALESCE(sp.region_name, r.region_name) AS region,
    sp.region_name AS sales_region,

    {{ mask_email('l.email') }} AS email,
    {{ mask_phone('l.phone') }} AS phone,
    CASE l.gender
        WHEN 'Male' THEN 'Nam'
        WHEN 'Female' THEN 'Nữ'
        ELSE 'Chưa xác định'
    END AS gender,
    {{ mask_birth_date('l.birth_date') }} AS birth_date,

    l.province,

    l.lead_source_name,
    l.lead_source_platform,
    l.pancake_platform,

    COALESCE(
        CASE l.status
            WHEN 'Lead' THEN 'Lead'
            WHEN 'Converted' THEN 'Đã chuyển đổi'
            WHEN 'Qualified' THEN 'Đã đạt chất lượng'
            WHEN 'Spam' THEN 'Spam'
            WHEN 'Opportunity' THEN 'Cơ hội'
            WHEN 'Interested' THEN 'Quan tâm'
            WHEN 'Do Not Contact' THEN 'Không liên lạc'
            WHEN 'Contacted' THEN 'Đã liên lạc'
            ELSE 'Khác'
        END,
        'Khác'
    ) AS lead_status,

    CASE l.qualification_status
        WHEN 'Qualified' THEN 'Đã đạt chất lượng'
        WHEN 'Unqualified' THEN 'Chưa đạt chất lượng'
        ELSE l.qualification_status
    END AS qualification_status,

    (l.lead_entry_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS lead_entry_date,
    (l.converted_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS converted_date,
    l.is_converted,

    l.time_to_convert_hours,
    l.current_lead_age_days,
    CASE
        WHEN l.current_lead_age_days < 7 THEN '1. < 7 ngày'
        WHEN l.current_lead_age_days <= 30 THEN '2. 7-30 ngày'
        WHEN l.current_lead_age_days <= 90 THEN '3. 31-90 ngày'
        ELSE '4. > 90 ngày'
    END AS lead_age_bucket,

    b.budget_label,
    b.budget_from AS budget_from_vnd,
    b.budget_to AS budget_to_vnd,

    d.demand_label,

    pp.preferred_products
FROM leads l
LEFT JOIN sales_persons sp
    ON l.assigned_to = sp.employee_email
LEFT JOIN budgets b
    ON l.budget_lead = b.lead_budget_id
LEFT JOIN demands d
    ON l.purpose_lead = d.lead_demand_id
LEFT JOIN regions r
    ON l.region = r.region_id
LEFT JOIN preferred_products pp
    ON l.lead_id = pp.lead_id
