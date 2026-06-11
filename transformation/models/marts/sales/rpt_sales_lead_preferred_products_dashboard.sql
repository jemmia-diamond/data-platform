{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_lead_preferred_products_lead_id ON {{ this }} (lead_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_lead_preferred_products_product_type ON {{ this }} (product_type)",
    ]
) }}

WITH preferred_products AS (
    SELECT
        pp.*,
        COUNT(*) OVER (PARTITION BY pp.lead_id) AS preferred_product_count,
        ROW_NUMBER() OVER (
            PARTITION BY pp.lead_id
            ORDER BY pp.idx NULLS LAST, pp.product_label, pp.product_type, pp.preferred_product_id
        ) AS preferred_product_rank
    FROM {{ ref('fct_sales_lead_preferred_products') }} pp
),

leads AS (
    SELECT * FROM {{ ref('rpt_sales_leads_dashboard') }}
),

lead_summary AS (
    SELECT * FROM {{ ref('rpt_sales_leads_order_summary_dashboard') }}
)

SELECT
    pp.preferred_product_id,
    pp.lead_id,
    pp.idx,
    pp.product_type,
    pp.product_label,
    pp.preferred_product_count,
    pp.preferred_product_rank,
    l.lead_name,
    l.sales_person_key,
    l.sales_person_name,
    l.sales_region_name,
    l.sales_city_name,
    l.sales_store_name,
    l.sales_position,
    l.region,
    l.sales_region,
    l.lead_region,
    l.email,
    l.phone,
    l.gender,
    l.birth_date,
    l.province,
    l.source,
    l.lead_source_name,
    l.lead_source_platform,
    l.pancake_platform,
    l.pancake_page_name,
    l.lead_status,
    l.qualification_status,
    l.lead_entry_date,
    l.converted_date,
    l.is_converted,
    l.budget_label,
    l.demand_label,
    l.preferred_product_count AS lead_preferred_product_count,
    ls.all_order_count,
    ls.all_order_total_price,
    ls.all_order_grand_total,
    ls.all_order_net_amount,
    ls.first_order_group_order_count,
    ls.first_order_group_total_price,
    CASE WHEN pp.preferred_product_count > 0
        THEN ls.all_order_count::numeric / pp.preferred_product_count
        ELSE NULL
    END AS allocated_all_order_count,
    CASE WHEN pp.preferred_product_count > 0
        THEN ls.all_order_total_price / pp.preferred_product_count
        ELSE NULL
    END AS allocated_all_order_total_price,
    CASE WHEN pp.preferred_product_count > 0
        THEN ls.first_order_group_total_price / pp.preferred_product_count
        ELSE NULL
    END AS allocated_first_order_group_total_price,
    l._db_updated_at
FROM preferred_products pp
LEFT JOIN leads l
    ON pp.lead_id = l.lead_id
LEFT JOIN lead_summary ls
    ON pp.lead_id = ls.lead_id
