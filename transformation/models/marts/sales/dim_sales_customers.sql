{{ config(
    materialized='table',
    schema='marts_sales'
) }}

-- Customer dimension — profile from CRM enriched with order metrics
-- Grain: 1 row = 1 customer
-- Source: int_crm__customers (Haravan + ERPNext unified profile)

WITH customers AS (
    SELECT * FROM {{ ref('int_crm__customers') }}
),

order_metrics AS (
    SELECT
        unified_customer_id,
        MIN(first_order_at)::date AS first_order_date,
        MAX(first_order_at)::date AS last_order_date,
        COUNT(*) AS total_orders,
        SUM(gross_amount) AS total_gross_amount,
        SUM(net_amount) AS total_net_amount,
        AVG(net_amount) AS avg_order_value
    FROM {{ ref('int_sales__orders') }}
    WHERE (order_number LIKE 'ORDER%'
               AND sales_channel NOT IN ('sendo', 'harafunnel')
               AND sales_channel NOT LIKE '%bhsc%'
               AND haravan_cancelled_status = 'uncancelled'
               AND haravan_confirmed_status = 'confirmed'
               AND (haravan_tags IS NULL OR haravan_tags NOT LIKE '%Lên bù cho đơn SO%')
               AND haravan_total_price > '120000')
       OR order_number NOT LIKE 'ORDER%'
    GROUP BY 1
)

SELECT
    -- === IDENTIFIERS ===
    c.unified_customer_id AS customer_id,
    c.erp_customer_id,
    c.haravan_customer_id AS hrv_customer_id,

    -- === PROFILE ===
    c.full_name,
    c.email,
    c.phone,
    CASE c.gender
        WHEN 'Male' THEN 'Nam'
        WHEN 'Female' THEN 'Nữ'
        ELSE 'Chưa xác định'
    END AS gender,
    c.birth_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int AS customer_age,
    CASE
        WHEN c.birth_date IS NULL THEN '8. Chưa xác định'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 20 THEN '1. <20'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 25 THEN '2. 21-25'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 30 THEN '3. 26-30'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 40 THEN '4. 31-40'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 50 THEN '5. 41-50'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 60 THEN '6. 51-60'
        ELSE '7. 61+'
    END AS age_group,

    -- === ADDRESS ===
    c.default_province,
    c.default_district,
    c.default_ward,
    c.default_country,

    -- === CRM & MARKETING ===
    c.customer_rank,
    c.rank,
    c.customer_journey,
    c.lead_name,
    c.lead_source_name,
    c.pancake_platform,
    c.accepts_marketing,
    c.haravan_tags AS tags,

    -- === ORDER METRICS ===
    m.first_order_date,
    m.last_order_date,
    COALESCE(m.total_orders, 0) AS total_orders,
    COALESCE(m.total_gross_amount, 0) AS total_gross_amount,
    COALESCE(m.total_net_amount, 0) AS total_net_amount,
    m.avg_order_value,
    COALESCE(m.total_orders, 0) > 1 AS is_repeat_customer,

    -- === TIMESTAMPS ===
    c.erp_created_at,
    c.haravan_created_at AS hrv_created_at,
    c.erp_updated_at,
    c.haravan_updated_at AS hrv_updated_at

FROM customers c
LEFT JOIN order_metrics m
    ON c.unified_customer_id = m.unified_customer_id
