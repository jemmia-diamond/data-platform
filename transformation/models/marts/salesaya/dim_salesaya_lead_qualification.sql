{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH contact_lead_links AS (
    SELECT * FROM {{ ref('int_crm__contact_lead_links') }}
),

leads AS (
    SELECT * FROM {{ ref('int_crm__leads') }}
),

users AS (
    SELECT * FROM {{ ref('stg_erpnext__users') }}
)

SELECT
    leads.lead_id                                                       AS id,
    CASE
        WHEN leads.qualification_status = 'Qualified' THEN true
        ELSE false
    END                                                                 AS qualified,
    contact_lead_links.pancake_conversation_id,
    leads.lead_owner                                                    AS pre_sales,
    leads.first_name                                                    AS name,
    leads.status                                                        AS lead_status,
    leads.budget_lead,
    leads.proposed_budget,
    users.pancake_id                                                    AS pre_sales_pancake_id,
    ''::text                                                            AS sales,
    ''::text                                                            AS sales_pancake_id
FROM contact_lead_links
JOIN leads
    ON contact_lead_links.lead_id = leads.lead_id
LEFT JOIN users
    ON users.email = leads.lead_owner
