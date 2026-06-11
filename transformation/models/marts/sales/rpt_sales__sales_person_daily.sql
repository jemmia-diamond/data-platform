{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_person_daily_date ON {{ this }} USING brin (date_actual)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_person_daily_person ON {{ this }} (sales_person_key)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_person_daily_region ON {{ this }} (region_name)",
    ]
) }}

WITH kpi AS (
    SELECT * FROM {{ ref('fct_sales_kpi_daily') }}
),

sales_persons AS (
    SELECT * FROM {{ ref('dim_sales_persons') }}
)

SELECT
    k.kpi_daily_key,
    k.sales_person_key,
    sp.sales_person_name,
    COALESCE(k.region_name, sp.region_name) AS region_name,
    sp.city_name,
    sp.store_name,
    sp.sales_position,
    sp.parent_sales_person,
    sp.is_active,
    sp.is_presale,
    k.date_actual,

    k.actual_gross_amount,
    k.actual_net_amount,
    k.actual_quantity,
    k.actual_orders,
    k.actual_customers,

    k.daily_target_amount,
    k.daily_target_quantity,
    k.daily_target_leads,

    k.mtd_actual_gross_amount,
    k.mtd_actual_net_amount,
    k.mtd_actual_quantity,
    k.mtd_actual_orders,

    k.monthly_target_amount,
    k.monthly_target_quantity,
    k.monthly_target_leads,

    k.day_of_month,
    k.days_in_month,
    k.month_progress_pct,
    k.mtd_achievement_gross_pct,
    k.mtd_achievement_qty_pct,

    CASE
        WHEN k.mtd_achievement_gross_pct IS NULL THEN 'Chưa có mục tiêu'
        WHEN k.mtd_achievement_gross_pct >= k.month_progress_pct THEN 'Đạt tiến độ'
        ELSE 'Chậm tiến độ'
    END AS kpi_progress_status

FROM kpi k
LEFT JOIN sales_persons sp
    ON k.sales_person_key = sp.sales_person_id

