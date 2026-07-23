{{
    config(
        materialized='view',
        schema='staging'
    )
}}

SELECT *
FROM {{ source('erpnext', 'buyback_exchanges') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Buyback Exchange'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
)
