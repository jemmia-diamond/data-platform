{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS call_log_id,

    -- Parties
    "from" AS from_phone,
    "to" AS to_phone,
    participant,
    participant_type,

    -- Call details
    type AS direction,
    status,
    disposition,
    duration::numeric AS duration_seconds,
    start_time::timestamp AS start_time,
    end_time::timestamp AS end_time,

    -- Recording & AI enrichment
    recording_url,
    summary,
    customer_sentinent AS customer_sentiment,
    provider,

    -- Agent attribution (sparse -- see model doc)
    agent,
    agent_id,
    agent_type,
    agent_name,
    employee_user_id,
    call_received_by,

    -- Flags & Configuration
    docstatus::int AS docstatus,
    idx::int AS idx,

    -- Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by

FROM {{ source('erpnext', 'call_logs') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'CRM Call Log'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
)
