{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_targets_monthly_sales_person_id ON {{ this }} (sales_person_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_targets_monthly_target_month_start ON {{ this }} USING brin (target_month_start)",
    ]
) }}

SELECT
    t.sales_target_id,
    t.sales_person_id,
    sp.region_name,
    t.fiscal_year,
    t.target_month,
    t.target_period_name,
    t.valid_from AS target_month_start,
    t.valid_to AS target_month_end,
    t.target_amount,
    t.target_quantity,
    t.target_lead_received,
    t.target_qualified_leads,
    t.target_qualified_to_orders,
    t.created_at,
    t.updated_at
FROM {{ ref('int_sales__sales_person_targets') }} t
LEFT JOIN {{ ref('dim_metabot_sales_persons') }} sp
    ON t.sales_person_id = sp.sales_person_id
WHERE t.valid_from >= DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '2 years'
