{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    name as promotion_id,
	start_date,
	end_date,
	is_active,
	is_expired,
	priority,
	SCOPE,
	product_category,
	promotion_month,
	promotion_type,
	discount_type,
	discount_amount,
	discount_percent,
	min_value,
	max_value,
	creation,
	promotion_group,
	title,
	description,
	modified_by,
	owner,
	_db_updated_at,
	_dlt_id,
	_dlt_load_id
FROM {{ source('erpnext', 'promotions') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Promotion'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
      AND dd.data::jsonb->>'promotion' = name
)
