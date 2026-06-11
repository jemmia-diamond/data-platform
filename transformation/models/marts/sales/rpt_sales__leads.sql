{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_entry_date ON {{ this }} USING brin (lead_entry_date)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_source ON {{ this }} (lead_source_name)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_sales_person ON {{ this }} (sales_person_key)",
    ]
) }}

WITH leads AS (
    SELECT * FROM {{ ref('fct_sales_leads') }}
),

sales_persons AS (
    SELECT * FROM {{ ref('dim_sales_persons') }}
),

lead_sources AS (
    SELECT * FROM {{ ref('dim_sales_lead_sources') }}
),

preferred_products AS (
    SELECT
        lead_id,
        COUNT(*) AS preferred_product_count,
        STRING_AGG(
            DISTINCT COALESCE(product_label, product_type, 'Chưa xác định'),
            ' + ' ORDER BY COALESCE(product_label, product_type, 'Chưa xác định')
        ) AS preferred_product_labels
    FROM {{ ref('fct_sales_lead_preferred_products') }}
    GROUP BY 1
)

SELECT
    l.lead_id,
    l.lead_name,
    l.sales_person_key,
    COALESCE(
        NULLIF(NULLIF(TRIM(l.sales_person_name), 'Chưa xác định'), 'Chưa gán sales'),
        NULLIF(NULLIF(TRIM(sp.sales_person_name), 'Chưa xác định'), 'Chưa gán sales'),
        'Chưa gán sales'
    ) AS sales_person_name,
    COALESCE(
        NULLIF(NULLIF(NULLIF(TRIM(l.sales_region), ''), 'Chưa xác định'), 'Chưa gán sales'),
        NULLIF(NULLIF(NULLIF(TRIM(sp.region_name), ''), 'Chưa xác định'), 'Chưa gán sales'),
        NULLIF(NULLIF(NULLIF(TRIM(l.region), ''), 'Chưa xác định'), 'Chưa gán sales'),
        'Chưa gán sales'
    ) AS sales_region_name,
    CASE
        WHEN l.sales_person_key IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.city_name', 'Chưa gán thành phố') }}
    END AS sales_city_name,
    CASE
        WHEN l.sales_person_key IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.store_name', 'Chưa gán cửa hàng') }}
    END AS sales_store_name,
    CASE
        WHEN l.sales_person_key IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.sales_position') }}
    END AS sales_position,
    CASE
        WHEN l.sales_person_key IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.parent_sales_person', 'Không có cấp trên') }}
    END AS parent_sales_person,

    l.region,
    l.sales_region,
    l.lead_region,
    COALESCE(
        NULLIF(NULLIF(NULLIF(TRIM(l.lead_region), ''), 'Chưa xác định'), 'Chưa gán sales'),
        NULLIF(NULLIF(NULLIF(TRIM(l.region), ''), 'Chưa xác định'), 'Chưa gán sales'),
        NULLIF(NULLIF(NULLIF(TRIM(l.sales_region), ''), 'Chưa xác định'), 'Chưa gán sales'),
        'Chưa xác định'
    ) AS lead_region_name,
    l.email,
    l.phone,
    l.gender,
    l.birth_date,
    l.province,

    l.source,
    l.lead_source_name,
    l.lead_source_platform,
    COALESCE(
        NULLIF(TRIM(l.pancake_platform), 'Chưa xác định'),
        NULLIF(TRIM(ls.pancake_platform), 'Chưa xác định'),
        'Chưa xác định'
    ) AS pancake_platform,
    l.pancake_page_name,
    l.pancake_page_id,
    l.pancake_customer_id,
    l.pancake_conversation_id,

    l.lead_status,
    l.qualification_status_raw,
    l.qualification_status,
    l.lead_entry_date,
    l.lead_entry_at,
    l.lead_entry_at_vn,
    l.converted_date,
    l.converted_at,
    l.converted_at_vn,
    l.is_converted,
    l.time_to_convert_hours,
    l.current_lead_age_days,
    l.lead_owner,
    l.is_assigned,
    l.assigned_to,

    l.budget_lead,
    {{ filter_text('l.budget_label', 'Chưa khai báo') }} AS budget_label,
    l.budget_from,
    l.budget_to,
    l.purpose_lead,
    {{ filter_text('l.demand_label', 'Chưa khai báo') }} AS demand_label,
    l.preferred_product_types,
    COALESCE(pp.preferred_product_count, 0) AS preferred_product_count,
    {{ filter_text('pp.preferred_product_labels', 'Chưa khai báo') }} AS preferred_product_labels,
    l._db_updated_at

FROM leads l
LEFT JOIN sales_persons sp
    ON l.sales_person_key = sp.sales_person_id
LEFT JOIN lead_sources ls
    ON l.source = ls.lead_source_id
LEFT JOIN preferred_products pp
    ON l.lead_id = pp.lead_id
