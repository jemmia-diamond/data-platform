{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS note_id,

    -- Parent link (the CRM Lead/Deal this note is attached to)
    parent AS parent_id,
    parenttype AS parent_type,
    parentfield AS parent_field,

    -- Content
    note AS note_content,
    type AS note_type,
    notify_to,
    added_by,
    added_on::timestamp AS added_on,

    -- Flags & Configuration
    docstatus::int AS docstatus,
    idx::int AS idx,

    -- Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by

FROM {{ source('erpnext', 'note') }}
