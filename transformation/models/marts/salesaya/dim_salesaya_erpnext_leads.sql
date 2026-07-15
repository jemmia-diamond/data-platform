{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    lead_id                                                              AS name,
    qualification_status,
    lead_owner,
    first_name,
    status,
    budget_lead,
    proposed_budget
FROM {{ ref('stg_erpnext__leads') }}
