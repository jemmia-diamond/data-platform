{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH contacts AS (
    SELECT * FROM {{ ref('stg_erpnext__contacts') }}
)

SELECT
    (contacts.dynamic_links -> 0) ->> 'link_name'                       AS lead_id,
    contacts.pancake_page_id,
    contacts.pancake_conversation_id,
    contacts.source_name,
    COUNT(*)                                                            AS total_records
FROM contacts
GROUP BY
    (contacts.dynamic_links -> 0) ->> 'link_name',
    contacts.pancake_page_id,
    contacts.pancake_conversation_id,
    contacts.source_name
