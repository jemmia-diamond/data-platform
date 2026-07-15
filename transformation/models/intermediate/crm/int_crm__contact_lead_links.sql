{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH contacts AS (
    SELECT * FROM {{ ref('stg_erpnext__contacts') }}
)

SELECT
    contacts.contact_id,
    contacts.pancake_conversation_id,
    contact_links.link_name                                                AS lead_id,
    contact_links.link_doctype
FROM contacts
CROSS JOIN LATERAL jsonb_to_recordset(contacts.dynamic_links)
    AS contact_links(link_name text, link_doctype text)
