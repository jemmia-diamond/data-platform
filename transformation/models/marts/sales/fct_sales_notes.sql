{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsn_parent_id ON {{ this }} (parent_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsn_added_on ON {{ this }} USING brin (added_on)",
    ]
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
FROM {{ ref('int_crm__notes') }}
