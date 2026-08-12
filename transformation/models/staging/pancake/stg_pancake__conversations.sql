{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id,
    type,
    customer_id,
    page_id,
    has_phone,
    message_count,
    post_id,
    inserted_at::timestamptz AS inserted_at,
    updated_at::timestamptz AS updated_at,
    _db_updated_at::timestamptz AS _db_updated_at,

    -- Profile / sender payload kept raw as JSONB (flattened downstream)
    page_customer,
    recent_phone_numbers,
    "from",
    last_sent_by,

    -- Tag + assignee histories (aggregated downstream)
    tag_histories,
    assignee_ids,
    current_assign_users,
    ad_ids,

    _dlt_load_id,
    _dlt_id

FROM {{ source('pancake', 'conversations') }}
