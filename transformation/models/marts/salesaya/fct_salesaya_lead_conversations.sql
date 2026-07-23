{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya lead-conversation feed (legacy find_lead_conversation) — record counts per lead,
-- Pancake page, Pancake conversation and source, derived from ALL ERPNext contacts (not the
-- pancake-customer-deduped int_crm__contacts, which would under-count). Sourced directly from
-- staging contacts to mirror the legacy view's grain exactly.
-- Grain: 1 row per (lead_id, pancake_page_id, pancake_conversation_id, source_name).
SELECT
    dynamic_links #>> '{0, link_name}' AS lead_id,
    pancake_page_id,
    pancake_conversation_id,
    source_name,
    COUNT(*)                          AS total_records
FROM {{ ref('stg_erpnext__contacts') }}
WHERE dynamic_links #>> '{0, link_name}' IS NOT NULL
GROUP BY
    dynamic_links #>> '{0, link_name}',
    pancake_page_id,
    pancake_conversation_id,
    source_name
