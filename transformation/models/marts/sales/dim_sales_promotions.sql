{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_dspromotion_id ON {{ this }} (promotion_id)"
    ]
) }}

WITH sales_persons AS (
    SELECT * FROM {{ ref('int_sales__promotions') }}
)

SELECT
    promotion_id,
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
	creation AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS creation_vn,
	promotion_group,
	title,
	description,
	modified_by,
	owner,
	_db_updated_at,
	_dlt_id,
	_dlt_load_id
FROM sales_persons
