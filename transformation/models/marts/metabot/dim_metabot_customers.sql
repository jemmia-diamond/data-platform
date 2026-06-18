{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot customer dimension. Grain: 1 row = 1 customer.
-- Source: int_crm__customers + order metrics from int_sales__orders (valid-orders filter).
-- Note: customers.lead_name actually stores a lead_id (ERPNext convention) → resolved to leads.lead_id.
-- total_orders counts DISTINCT split_order_group to stay consistent with metabot.orders grain.

WITH customers AS (
    SELECT * FROM {{ ref('int_crm__customers') }}
),

order_metrics AS (
    SELECT
        unified_customer_id,
        (MIN(first_order_at) AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS first_order_date,
        (MAX(first_order_at) AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS last_order_date,
        COUNT(DISTINCT COALESCE(split_order_group, unified_sales_order_id)) AS total_orders,
        SUM(gross_amount) AS total_gross_amount,
        SUM(net_amount) AS total_net_amount,
        AVG(net_amount) AS avg_order_value
    FROM {{ ref('int_sales__orders') }}
    WHERE {{ metabot_valid_orders_filter() }}
    GROUP BY 1
)

SELECT
    c.unified_customer_id AS customer_id,
    {{ mask_name('c.full_name') }} AS full_name,
    {{ mask_email('c.email') }} AS email,
    {{ mask_phone('c.phone') }} AS phone,
    CASE c.gender
        WHEN 'Male' THEN 'Nam'
        WHEN 'Female' THEN 'Nữ'
        ELSE 'Chưa xác định'
    END AS gender,
    {{ mask_birth_date('c.birth_date') }} AS birth_date,
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

    c.default_province,
    c.default_district,

    c.customer_rank,
    c.rank,
    c.customer_journey,

    NULLIF(c.lead_name, '') AS lead_id,
    c.lead_source_name,
    c.pancake_platform,
    c.accepts_marketing,

    m.first_order_date,
    m.last_order_date,
    (CURRENT_DATE - m.last_order_date) AS days_since_last_order,
    COALESCE(m.total_orders, 0) AS total_orders,
    COALESCE(m.total_gross_amount, 0) AS total_gross_amount_vnd,
    COALESCE(m.total_net_amount, 0) AS total_net_amount_vnd,
    m.avg_order_value AS avg_order_value_vnd,
    COALESCE(m.total_orders, 0) > 1 AS is_repeat_customer

FROM customers c
LEFT JOIN order_metrics m
    ON c.unified_customer_id = m.unified_customer_id
