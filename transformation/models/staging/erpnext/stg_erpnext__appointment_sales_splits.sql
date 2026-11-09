{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested_splits AS (
    SELECT
        name AS parent_appointment_id,
        jsonb_array_elements(sales_splits::jsonb) AS split,
        _db_updated_at
    FROM {{ source('erpnext', 'appointments') }}
    WHERE sales_splits IS NOT NULL
      AND sales_splits::text <> '[]'
      AND name NOT IN (
          SELECT deleted_name
          FROM {{ source('erpnext', 'deleted_documents') }}
          WHERE deleted_doctype = 'Appointment'
            AND (restored IS NULL OR restored = 0)
      )
)

SELECT
    split ->> 'name' AS appointment_sales_split_id,
    parent_appointment_id AS appointment_id,
    split ->> 'sales_person' AS sales_person_id,
    -- percentage is typed by the user and is the source of truth;
    -- commission_amount is computed client-side and can go stale when the group total changes
    (split ->> 'percentage')::numeric AS percentage,
    (split ->> 'commission_amount')::numeric AS commission_amount,
    split ->> 'reason' AS reason,
    (split ->> 'idx')::integer AS idx,
    (split ->> 'creation')::timestamp AS created_at,
    (split ->> 'modified')::timestamp AS updated_at,
    split ->> 'owner' AS owner,
    split ->> 'modified_by' AS modified_by,
    _db_updated_at::timestamp AS _db_updated_at
FROM unnested_splits
