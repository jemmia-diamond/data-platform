{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    call_log_id,

    from_phone,
    to_phone,

    -- Split participant into typed FKs so downstream models can join directly
    -- instead of repeating the CASE on participant_type every time.
    CASE WHEN participant_type = 'Lead' THEN participant END AS participant_lead_id,
    CASE WHEN participant_type = 'Customer' THEN participant END AS participant_customer_id,
    participant_type,

    CASE direction
        WHEN 'Incoming' THEN 'Gọi đến'
        WHEN 'Outgoing' THEN 'Gọi đi'
        ELSE 'Chưa xác định'
    END AS direction,
    direction AS direction_raw,
    status,
    disposition,
    duration_seconds,
    start_time,
    start_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS start_time_vn,
    end_time,

    recording_url,
    summary,
    customer_sentiment,
    provider,

    agent,
    agent_id,
    agent_type,
    agent_name,
    employee_user_id,
    call_received_by,

    created_at,
    updated_at,
    owner,
    modified_by

FROM {{ ref('stg_erpnext__call_logs') }}
