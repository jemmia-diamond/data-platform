{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested_products AS (
    SELECT 
        name AS parent_lead_id,
        jsonb_array_elements(preferred_product_types::jsonb) AS product,
        _db_updated_at
    FROM {{ source('erpnext', 'leads') }}
    WHERE preferred_product_types IS NOT NULL 
      AND preferred_product_types::text <> '[]'
      AND name NOT IN (
          SELECT deleted_name
          FROM {{ source('erpnext', 'deleted_documents') }}
          WHERE deleted_doctype = 'Lead'
            AND (restored IS NULL OR restored = 0)
      )
)

SELECT 
    product ->> 'name' AS preferred_product_id,
    parent_lead_id AS lead_id,
    product ->> 'product_type' AS product_type,
    (product ->> 'idx')::integer AS idx,
    (product ->> 'creation')::timestamp AS created_at,
    (product ->> 'modified')::timestamp AS updated_at,
    product ->> 'owner' AS owner,
    product ->> 'modified_by' AS modified_by,
    (product ->> 'docstatus')::integer AS docstatus,
    _db_updated_at::timestamp AS _db_updated_at
FROM unnested_products
