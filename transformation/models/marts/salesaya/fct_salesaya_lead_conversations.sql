{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya lead-conversation feed — record counts per lead, Pancake page, Pancake conversation
-- and source, derived from contacts. Grain: 1 row per (lead_id, pancake_page_id,
-- pancake_conversation_id, source_name).
SELECT
    primary_lead_id          AS lead_id,
    pancake_page_id,
    pancake_conversation_id,
    source_name,
    COUNT(*)                 AS total_records
FROM {{ ref('int_crm__contacts') }}
WHERE primary_lead_id IS NOT NULL
GROUP BY
    primary_lead_id,
    pancake_page_id,
    pancake_conversation_id,
    source_name
