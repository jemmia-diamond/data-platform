{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    c.id AS conversation_id,

    -- Customer profile from embedded JSONB (higher coverage than raw_pancake.page_customers)
    c.page_customer->>'name'                                              AS customer_name,
    c.recent_phone_numbers->0->>'phone_number'                            AS customer_phone,
    c.page_customer->>'gender'                                            AS customer_gender,
    NULLIF(c.page_customer->>'birthday', '')                              AS customer_birth_date,
    NULLIF(c.page_customer->>'lives_in', '')                              AS customer_lives_in,
    COALESCE(c."from"->>'avatar_url', c.page_customer->>'avatar_url')     AS customer_avatar_url,

    -- Assignee (latest)
    c.assignee_ids->0->>'id'                                              AS assignee_user_id,
    c.current_assign_users->0->>'name'                                    AS assignee_user_name,

    -- Tags: latest action='add' per tag id, aggregated to text[]
    (
        SELECT array_agg(tag_label)
        FROM (
            SELECT DISTINCT ON (je->'payload'->'tag'->>'id')
                   je->'payload'->'tag'->>'text' AS tag_label
            FROM jsonb_array_elements(c.tag_histories) AS je
            WHERE je->'payload'->>'action' = 'add'
            ORDER BY je->'payload'->'tag'->>'id', (je->>'inserted_at') DESC
        ) t
    )                                                                     AS tags

FROM {{ ref('stg_pancake__conversations') }} c
