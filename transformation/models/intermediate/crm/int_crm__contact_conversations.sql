{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    contact_id,
    (dynamic_links -> 0) ->> 'link_name'                                   AS lead_id,
    pancake_page_id,
    pancake_conversation_id,
    source_name
FROM {{ ref('stg_erpnext__contacts') }}
