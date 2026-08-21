{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fscl_start_time ON {{ this }} USING brin (start_time)",
      "CREATE INDEX IF NOT EXISTS idx_fscl_participant_lead_id ON {{ this }} (participant_lead_id)",
      "CREATE INDEX IF NOT EXISTS idx_fscl_participant_customer_id ON {{ this }} (participant_customer_id)",
    ]
) }}

SELECT
    call_log_id,

    {{ mask_phone('from_phone') }} AS from_phone,
    {{ mask_phone('to_phone') }} AS to_phone,

    -- FK to fct_sales_leads.lead_id / dim_sales_customers.customer_id -- only ~5% of
    -- call logs have a participant linked (see model doc), most are NULL
    participant_lead_id,
    participant_customer_id,
    participant_type,

    direction,
    direction_raw,
    status,
    disposition,
    duration_seconds,
    start_time,
    start_time_vn,
    end_time,

    recording_url,
    summary,
    customer_sentiment,
    provider,

    -- Agent attribution -- populated for a small minority of rows only (see model doc)
    agent,
    agent_id,
    agent_type,
    agent_name,
    employee_user_id,
    call_received_by,

    created_at,
    updated_at

FROM {{ ref('int_crm__call_logs') }}
