{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH contacts AS (
    SELECT * FROM {{ ref('int_crm__contact_conversations') }}
)

SELECT
    contacts.lead_id,
    contacts.pancake_page_id,
    contacts.pancake_conversation_id,
    contacts.source_name,
    COUNT(*)                                                            AS total_records
FROM contacts
GROUP BY
    contacts.lead_id,
    contacts.pancake_page_id,
    contacts.pancake_conversation_id,
    contacts.source_name
