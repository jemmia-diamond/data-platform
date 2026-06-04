{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    name AS purchase_purpose_id,
    title AS purpose_name,
    docstatus::int AS docstatus,
    idx::int AS idx,
    owner,
    modified_by,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'purchase_purposes') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Purchase Purpose'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
      AND dd.data::jsonb->>'title' = title
)
