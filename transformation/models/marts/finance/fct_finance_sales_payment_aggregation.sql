{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_split_order_group ON {{ this }} (split_order_group)",
      "CREATE INDEX IF NOT EXISTS idx_fso_split_order_group_name ON {{ this }} (split_order_group_name)"
    ]
) }}

with
get_order_total_price as (
	select
		split_order_group,
		max(split_order_group_name) AS split_order_group_name,
	-- 	COALESCE(max(order_date) FILTER (WHERE id::character varying::text = split_order_group), min(order_date)) AS real_created_at_7_utc,
		min(order_date) as order_date,
		max(haravan_created_date) AS haravan_created_date,
		max(ref_order_id) AS ref_order_id,
		max(main_branch) AS branch_code,
		max(order_customer_type) AS order_customer_type,
		max(haravan_customer_id) AS haravan_customer_id,
		max(sales_channel_raw) AS source,
		max(group_total_price) AS total_group_price,
		sum(total_paid_amount) AS total_group_revenue,
		count(*) AS split_order_count,
		count(*) FILTER (WHERE cancelled_status::text = 'uncancelled'::text) AS uncancelled_count,
		CASE
		    WHEN count(*) FILTER (WHERE cancelled_status::text = 'uncancelled'::text) = count(*) THEN 'uncancelled'::text
		    WHEN count(*) FILTER (WHERE cancelled_status::text = 'uncancelled'::text) = 0 THEN 'all_cancelled'::text
		    ELSE 'partial_cancelled'::text
		END AS group_cancelled_status
	from {{ ref('fct_finance_sales_payment')}}
	GROUP BY split_order_group
	HAVING count(*) FILTER (WHERE cancelled_status::text = 'uncancelled'::text) > 0
)
select
	split_order_group,
    split_order_group_name,
    order_date,
	CASE
		WHEN branch_code = '72NCT'::text THEN 'Hồ Chí Minh'::text
		WHEN branch_code = '63KM'::text THEN 'Hà Nội'::text
		WHEN branch_code = '209Đ30T4'::text THEN 'Cần Thơ'::text
		ELSE branch_code
	END AS branch_name,
    order_customer_type,
    haravan_customer_id,
    ref_order_id,
    split_order_count,
    group_cancelled_status,
    CASE
		WHEN total_group_price <= 0::numeric THEN 'Không xác định'::text
		WHEN total_group_revenue >= (total_group_price * 0.3) THEN 'Đã cọc đủ'::text
		ELSE 'Chưa cọc đủ'::text
    END AS deposit_status,
    source,
    total_group_price,
    total_group_revenue,
    total_group_price - total_group_revenue AS total_group_balance
from get_order_total_price





