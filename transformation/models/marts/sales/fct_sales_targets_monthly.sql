{{ config(
    materialized='materialized_view',
    schema='marts_sales'
) }}

WITH targets AS (
    SELECT * FROM {{ ref('int_sales__sales_person_targets') }}
)

SELECT
    sales_target_id AS sales_target_key,
    sales_target_id,
    sales_person_id AS sales_person_key,
    fiscal_year,
    target_period_name,
    target_month,
    valid_from AS target_month_start,
    valid_to AS target_month_end,
    target_amount,
    target_quantity,
    target_lead_received,
    target_qualified_leads,
    target_qualified_to_orders,
    target_owner,
    created_at,
    updated_at
FROM targets
