{{ config(
    materialized='view',
    schema='staging'
) }}

select
    to_date(time_id::text, 'YYYYMMDD') as time_id,
	item_code,
	concat(to_date(time_id::text, 'YYYYMMDD'), '_', item_code) as time_item_key,
	item_name,
	item_index,
	description,
	formula_type,
	category,
	formula_front_end,
	formula,
	amount,
	prev_amount,
	hidden,
	is_bold,
	is_italic,
	sort_order,
	from_date,
	to_date,
	sync_at
from {{ source('misa', 'cash_flow_monthly_fact') }}
