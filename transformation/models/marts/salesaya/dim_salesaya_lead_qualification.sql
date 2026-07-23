{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya lead-qualification feed — one row per lead with its qualification flag, status, budget,
-- pre-sales owner and the owner's Pancake id, plus the contact's Pancake conversation.
-- Grain: 1 row per (lead, contact) — a lead may surface across multiple conversations.
SELECT
    l.lead_id                               AS id,
    (l.qualification_status = 'Qualified')  AS qualified,
    c.pancake_conversation_id,
    l.lead_owner                            AS pre_sales,
    l.first_name                            AS name,
    l.status                                AS lead_status,
    l.budget_lead,
    l.proposed_budget,
    l.owner_pancake_id                      AS pre_sales_pancake_id,
    ''::text                                AS sales,
    ''::text                                AS sales_pancake_id
FROM {{ ref('int_crm__leads') }} l
LEFT JOIN {{ ref('int_crm__contacts') }} c
    ON c.primary_lead_id = l.lead_id
