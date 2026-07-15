{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    contact_id                                                           AS name,
    pancake_conversation_id,
    pancake_page_id,
    dynamic_links                                                        AS links,
    created_at                                                           AS creation,
    phones                                                               AS phone_nos,
    emails                                                               AS email_ids,
    first_name,
    last_name,
    source
FROM {{ ref('stg_erpnext__contacts') }}
