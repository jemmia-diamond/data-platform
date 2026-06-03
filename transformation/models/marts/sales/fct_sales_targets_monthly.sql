{{ config(
    materialized='table',
    schema='marts_sales'
) }}

WITH targets AS (
    SELECT * FROM {{ ref('int_sales__sales_person_targets') }}
),

persons AS (
    SELECT sales_person_id, sales_region_name
    FROM {{ ref('dim_sales_persons') }}
)

SELECT
    t.sales_target_id AS sales_target_key,
    t.sales_target_id,
    t.sales_person_id AS sales_person_key,
    p.sales_region_name,
    t.fiscal_year,
    t.target_period_name,
    t.target_month,
    t.valid_from AS target_month_start,
    t.valid_to AS target_month_end,
    t.target_amount,
    t.target_quantity,
    t.target_lead_received,
    t.target_qualified_leads,
    t.target_qualified_to_orders,
    t.target_owner,
    t.created_at,
    t.updated_at
FROM targets t
LEFT JOIN persons p
    ON t.sales_person_id = p.sales_person_id
