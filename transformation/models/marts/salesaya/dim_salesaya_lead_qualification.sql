{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH contacts AS (
    SELECT * FROM {{ ref('stg_erpnext__contacts') }}
),

leads AS (
    SELECT * FROM {{ ref('stg_erpnext__leads') }}
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
    contacts.pancake_conversation_id,
    leads.lead_owner                                                    AS pre_sales,
    leads.first_name                                                    AS name,
    leads.status                                                        AS lead_status,
    leads.budget_lead,
    leads.proposed_budget,
    users.pancake_id                                                    AS pre_sales_pancake_id,
    ''::text                                                            AS sales,
    ''::text                                                            AS sales_pancake_id
FROM contacts
CROSS JOIN LATERAL jsonb_to_recordset(contacts.dynamic_links)
    AS contact_links(link_name text, link_doctype text)
JOIN leads
    ON contact_links.link_name = leads.lead_id
LEFT JOIN users
    ON users.email = leads.lead_owner
