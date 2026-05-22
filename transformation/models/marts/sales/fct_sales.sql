{{ config(
    materialized='table',
    schema='marts_sales'
) }}

SELECT
    -- Dimensions
    erp_sales_order_id AS order_key,
    unified_customer_id AS customer_key,
    business_date,
    sales_channel,
    erp_status AS status,
    
    -- Marketing Context
    utm_source,
    utm_medium,
    utm_campaign,

    -- Metrics
    gross_amount,
    tax_amount,
    COALESCE(haravan_discount_amount, 0) + COALESCE(erp_discount_amount, 0) AS total_discount_amount,
    net_amount,
    paid_amount,
    outstanding_amount,

    -- Flags
    CASE WHEN outstanding_amount <= 0 THEN TRUE ELSE FALSE END AS is_fully_paid

FROM {{ ref('int_sales__orders') }}
