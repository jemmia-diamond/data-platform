{{ config(
    materialized='materialized_view',
    schema='marts_sales'
) }}

WITH daily_actuals AS (
    SELECT
        sales_person_key,
        order_date AS date_actual,
        SUM(allocated_gross_amount) AS actual_gross_amount,
        SUM(allocated_net_amount) AS actual_net_amount,
        SUM(allocated_quantity) AS actual_quantity,
        COUNT(DISTINCT order_id) AS actual_orders,
        COUNT(DISTINCT customer_id) AS actual_customers
    FROM {{ ref('fct_sales_attributions') }}
    GROUP BY 1, 2
),

target_months AS (
    SELECT
        t.sales_person_key,
        t.target_month_start,
        t.target_month_end,
        EXTRACT(DAY FROM t.target_month_end)::int AS days_in_month,
        t.target_amount AS monthly_target_amount,
        t.target_quantity AS monthly_target_quantity,
        t.target_lead_received AS monthly_target_leads
    FROM {{ ref('fct_sales_targets_monthly') }} t
    WHERE t.target_month_start >= DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '2 years'
),

daily_targets AS (
    SELECT
        tm.sales_person_key,
        d.date_actual,
        tm.monthly_target_amount / tm.days_in_month AS daily_target_amount,
        tm.monthly_target_quantity / tm.days_in_month AS daily_target_quantity,
        tm.monthly_target_leads::numeric / tm.days_in_month AS daily_target_leads,
        tm.monthly_target_amount,
        tm.monthly_target_quantity,
        tm.monthly_target_leads,
        EXTRACT(DAY FROM d.date_actual)::int AS day_of_month,
        tm.days_in_month
    FROM target_months tm
    INNER JOIN {{ ref('dim_dates') }} d
        ON d.date_actual BETWEEN tm.target_month_start AND tm.target_month_end
),

kpi AS (
    SELECT
        COALESCE(a.sales_person_key, t.sales_person_key) AS sales_person_key,
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
    FULL OUTER JOIN daily_targets t
        ON a.sales_person_key = t.sales_person_key
       AND a.date_actual = t.date_actual
)

SELECT
    sales_person_key || ':' || date_actual::text AS kpi_daily_key,
    sales_person_key,
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
    day_of_month::numeric / days_in_month AS month_progress_pct,

    CASE WHEN monthly_target_amount > 0
         THEN ROUND(mtd_actual_gross_amount / monthly_target_amount, 4)
         ELSE NULL
    END AS mtd_achievement_gross_pct,

    CASE WHEN monthly_target_quantity > 0
         THEN ROUND(mtd_actual_quantity / monthly_target_quantity, 4)
         ELSE NULL
    END AS mtd_achievement_qty_pct

FROM kpi
