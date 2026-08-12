{{ config(
    materialized='incremental',
    schema='marts_pancake',
    unique_key='conversation_id',
    on_schema_change='append_new_columns',
    post_hook=[
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_fct_pc_conv_id ON {{ this }} (conversation_id)",
        "CREATE INDEX IF NOT EXISTS idx_fct_pc_updated ON {{ this }} (updated_at DESC)",
        "CREATE INDEX IF NOT EXISTS idx_fct_pc_customer ON {{ this }} (customer_id)",
        "CREATE INDEX IF NOT EXISTS idx_fct_pc_phone ON {{ this }} (conversation_id) WHERE has_phone = true",
    ]
) }}

SELECT
    c.id                                                          AS conversation_id,
    c.customer_id,
    c.page_id,
    c.type,
    c.inserted_at,
    c.updated_at,
    c._db_updated_at,
    c.has_phone,
    c.message_count,
    c.post_id,
    c.ad_ids,

    -- Page context
    p.name                                                        AS page_name,
    -- platform from the page table (LEFT JOIN, may be NULL for pages not listed
    -- by the current user access token).
    CASE
        WHEN p.platform = 'personal_zalo'
         AND c.page_id IN (
                'pzl_488577139896879905',
                'pzl_833581016608002860',
                'pzl_779852793569717677',
                'pzl_414930725736878626'
             )
        THEN 'personal_zalo_koc'
        ELSE p.platform
    END                                                           AS platform,

    -- Customer profile (flattened from embedded JSONB)
    prof.customer_name,
    prof.customer_phone,
    prof.customer_gender,
    CASE
        WHEN prof.customer_birth_date IS NULL THEN NULL
        WHEN prof.customer_birth_date !~ '^\d{4}-\d{2}-\d{2}$' THEN NULL
        WHEN date_part('year', prof.customer_birth_date::date) = 1903 THEN NULL
        ELSE prof.customer_birth_date::date
    END                                                           AS customer_birth_date,
    prof.customer_lives_in,
    prof.customer_avatar_url,
    prof.assignee_user_id,
    prof.assignee_user_name,
    prof.tags,

    -- Message timing derived from conversation (no messages table needed).
    -- Only the LAST sender has an exact timestamp (= updated_at); the other side
    -- is NULL because the Pancake conversation API does not store it.
    c.updated_at                                                  AS latest_message_at,
    (c.last_sent_by->>'id') = c.page_id                           AS last_sender_is_sales,
    CASE WHEN (c.last_sent_by->>'id') = c.page_id
         THEN c.updated_at END                                     AS last_sales_message_at,
    CASE WHEN (c.last_sent_by->>'id') IS NOT NULL
          AND (c.last_sent_by->>'id') <> c.page_id
         THEN c.updated_at END                                     AS last_customer_message_at

FROM {{ ref('stg_pancake__conversations') }} c
LEFT JOIN {{ ref('stg_pancake__pages') }} p
    ON p.id = c.page_id
LEFT JOIN {{ ref('int_pancake__conversation_profile') }} prof
    ON prof.conversation_id = c.id
WHERE c.type = 'INBOX'
{% if is_incremental() %}
  AND c._db_updated_at > (SELECT max(_db_updated_at) FROM {{ this }})
{% endif %}
