{{ config(
    materialized='view',
    schema='staging'
) }}

select
    to_date(time_id::text, 'YYYYMMDD') as time_id,
	item_code,
	concat(to_date(time_id::text, 'YYYYMMDD'), '_', item_code) as time_item_key,
	item_name,
	amount,
	prev_amount,
	from_date,
	to_date,
	sync_at,
	created_at
from {{ source('misa', 'income_statement_monthly_fact') }}
