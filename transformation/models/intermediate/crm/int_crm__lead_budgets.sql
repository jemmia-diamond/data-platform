{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    lead_budget_id,
    budget_label,
    budget_from,
    budget_to
FROM {{ ref('stg_erpnext__lead_budgets') }}
