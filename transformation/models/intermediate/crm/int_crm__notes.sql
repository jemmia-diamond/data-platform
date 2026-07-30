{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    note_id,
    parent_id,
    parent_type,
    parent_field,
    note_content,
    note_type,
    notify_to,
    added_by,
    added_on,
    created_at,
    updated_at,
    owner

FROM {{ ref('stg_erpnext__notes') }}
