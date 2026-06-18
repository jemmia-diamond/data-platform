{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_kpi_daily_sales_person_key ON {{ this }} (sales_person_key)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_kpi_daily_date_actual ON {{ this }} USING brin (date_actual)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_kpi_daily_region_name ON {{ this }} (region_name)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_kpi_daily_person_date ON {{ this }} (sales_person_key, date_actual)",
    ]
) }}

WITH daily_actuals AS (
    SELECT
        st.sales_person_id AS sales_person_key,
        io.first_order_at::date AS date_actual,
        SUM(st.allocated_amount) AS actual_gross_amount,
        -- Assuming net amount is gross amount for now, adjust if int_sales__sales_teams has net
        SUM(st.allocated_amount) AS actual_net_amount,
        SUM(io.total_qty) AS actual_quantity,
        COUNT(DISTINCT io.unified_sales_order_id) AS actual_orders,
        COUNT(DISTINCT io.unified_customer_id) AS actual_customers
    FROM {{ ref('int_sales__orders') }} io
    JOIN {{ ref('int_sales__sales_teams') }} st
        ON io.erp_sales_order_id = st.erp_sales_order_id
    WHERE {{ metabot_valid_orders_filter() }}
    GROUP BY 1, 2
),

daily_targets AS (
    SELECT
        tm.sales_person_id AS sales_person_key,
        sp.region_name,
        dd.date AS date_actual,
        tm.target_amount::numeric / EXTRACT(DAY FROM tm.target_month_end)::int AS daily_target_amount,
        tm.target_quantity::numeric / EXTRACT(DAY FROM tm.target_month_end)::int AS daily_target_quantity,
        tm.target_lead_received::numeric / EXTRACT(DAY FROM tm.target_month_end)::int AS daily_target_leads,
        tm.target_amount AS monthly_target_amount,
        tm.target_quantity AS monthly_target_quantity,
        tm.target_lead_received AS monthly_target_leads,
        EXTRACT(DAY FROM dd.date)::int AS day_of_month,
        EXTRACT(DAY FROM tm.target_month_end)::int AS days_in_month
    FROM {{ ref('fct_metabot_targets_monthly') }} tm
    INNER JOIN {{ ref('dim_metabot_dates') }} dd
        ON dd.date BETWEEN tm.target_month_start AND tm.target_month_end
    LEFT JOIN {{ ref('dim_metabot_sales_persons') }} sp
        ON tm.sales_person_id = sp.sales_person_id
),

persons AS (
    SELECT sales_person_id, region_name
    FROM {{ ref('dim_metabot_sales_persons') }}
),

kpi AS (
    SELECT
        COALESCE(a.sales_person_key, t.sales_person_key) AS sales_person_key,
        COALESCE(pa.region_name, pt.region_name) AS region_name,
        COALESCE(a.date_actual, t.date_actual) AS date_actual,

        COALESCE(a.actual_gross_amount, 0) AS actual_gross_amount,
        COALESCE(a.actual_net_amount, 0) AS actual_net_amount,
        COALESCE(a.actual_quantity, 0) AS actual_quantity,
        COALESCE(a.actual_orders, 0) AS actual_orders,
        COALESCE(a.actual_customers, 0) AS actual_customers,

        COALESCE(t.daily_target_amount, 0) AS daily_target_amount,
        COALESCE(t.daily_target_quantity, 0) AS daily_target_quantity,
        COALESCE(t.daily_target_leads, 0) AS daily_target_leads,

        COALESCE(t.monthly_target_amount, 0) AS monthly_target_amount,
        COALESCE(t.monthly_target_quantity, 0) AS monthly_target_quantity,
        COALESCE(t.monthly_target_leads, 0) AS monthly_target_leads,

        COALESCE(t.day_of_month, EXTRACT(DAY FROM a.date_actual)::int) AS day_of_month,
        COALESCE(t.days_in_month, EXTRACT(DAY FROM (DATE_TRUNC('month', a.date_actual) + INTERVAL '1 month' - INTERVAL '1 day')::date)::int) AS days_in_month
    FROM daily_actuals a
    LEFT JOIN persons pa
        ON a.sales_person_key = pa.sales_person_id
    FULL OUTER JOIN daily_targets t
        ON a.sales_person_key = t.sales_person_key
       AND a.date_actual = t.date_actual
    LEFT JOIN persons pt
        ON t.sales_person_key = pt.sales_person_id
),

kpi_mtd AS (
    SELECT
        sales_person_key,
        region_name,
        date_actual,

        actual_gross_amount,
        actual_net_amount,
        actual_quantity,
        actual_orders,
        actual_customers,

        daily_target_amount,
        daily_target_quantity,
        daily_target_leads,

        SUM(actual_gross_amount) OVER (
            PARTITION BY sales_person_key, DATE_TRUNC('month', date_actual)
            ORDER BY date_actual
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS mtd_actual_gross_amount,

        SUM(actual_net_amount) OVER (
            PARTITION BY sales_person_key, DATE_TRUNC('month', date_actual)
            ORDER BY date_actual
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS mtd_actual_net_amount,

        SUM(actual_quantity) OVER (
            PARTITION BY sales_person_key, DATE_TRUNC('month', date_actual)
            ORDER BY date_actual
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS mtd_actual_quantity,

        SUM(actual_orders) OVER (
            PARTITION BY sales_person_key, DATE_TRUNC('month', date_actual)
            ORDER BY date_actual
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS mtd_actual_orders,

        monthly_target_amount,
        monthly_target_quantity,
        monthly_target_leads,

        day_of_month,
        days_in_month,
        day_of_month::numeric / days_in_month AS month_progress_pct
    FROM kpi
)

SELECT
    sales_person_key || ':' || date_actual::text AS kpi_daily_key,
    sales_person_key,
    region_name,
    date_actual,

    actual_gross_amount,
    actual_net_amount,
    actual_quantity,
    actual_orders,
    actual_customers,

    daily_target_amount,
    daily_target_quantity,
    daily_target_leads,

    mtd_actual_gross_amount,
    mtd_actual_net_amount,
    mtd_actual_quantity,
    mtd_actual_orders,

    monthly_target_amount,
    monthly_target_quantity,
    monthly_target_leads,

    day_of_month,
    days_in_month,
    month_progress_pct,

    CASE WHEN monthly_target_amount > 0
         THEN ROUND(mtd_actual_gross_amount / monthly_target_amount, 4)
         ELSE NULL
    END AS mtd_achievement_gross_pct,

    CASE WHEN monthly_target_quantity > 0
         THEN ROUND(mtd_actual_quantity / monthly_target_quantity, 4)
         ELSE NULL
    END AS mtd_achievement_qty_pct

FROM kpi_mtd
