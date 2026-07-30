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
	formula_front_end,
	category,
	amount,
	prev_amount,
	from_date,
	to_date,
	sync_at
from {{ source('misa', 'balance_sheet_monthly_fact') }}
