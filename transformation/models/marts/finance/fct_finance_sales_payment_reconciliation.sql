{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_fso_sales_channel ON {{ this }} (sales_channel)",
      "CREATE INDEX IF NOT EXISTS idx_fso_date_customer ON {{ this }} (order_date, customer_id)",
    ]
) }}



with
int_order as (
	select *
	from {{ ref('int_sales__orders')}}
),
group_total AS (
    SELECT
        COALESCE(split_order_group, unified_sales_order_id) AS split_key,
        SUM(haravan_total_price::numeric) AS group_total_price
    FROM int_order
    where haravan_cancelled_status = 'uncancelled'
    GROUP BY COALESCE(split_order_group, unified_sales_order_id)
),
erp_order_payment_entry as (
	select *
	from {{ ref('stg_erpnext__sales_payment_entries')}}
),
get_sales_info as (
	select
		distinct
			sa.order_id,
			ds.city_name
	from {{ ref('fct_sales_attributions')}} sa
	left join {{ ref('dim_sales_persons')}} ds on ds.sales_person_id = sa.sales_person_key
)
select
	a.unified_sales_order_id as order_id,
	a.haravan_order_id,
	a.order_number,
	a.erp_sales_order_id,
	a.haravan_order_id,
	a.split_order_group,
	a.split_order_group_name,
	a.haravan_total_price,
	a.real_order_date,
	a.first_order_at,
	g.group_total_price,
	e.payment_date,
	e.allocated_amount,
	e.paid_amount,
	e.payment_order_status,
	e.parentfield,
	CASE
		WHEN group_total_price <= 0::numeric THEN 'Không xác định'::text
		WHEN e.allocated_amount >= (group_total_price * 0.3) THEN 'Đã cọc đủ'::text
		ELSE 'Chưa cọc đủ'::text
	END AS deposit_status,
	gs.city_name as main_branch,
	haravan_cancelled_status as cancelled_status,
	CASE a.sales_channel
        WHEN 'pos-cua-hang-hn' THEN 'POS - Hà Nội'
        WHEN 'pos-cua-hang-hcm' THEN 'POS - Hồ Chí Minh'
        WHEN 'pos cua hang can tho' THEN 'POS - Cần Thơ'
        WHEN 'pos' THEN 'POS - Chưa xác định'
        WHEN 'staff' THEN 'Nhân viên'
        ELSE 'Kênh online'
    END AS sales_channel,
	mode_of_payment as raw_payment_mode,
	payment_ref as payment_ref,
	bank_account,
	bank,
	bank_account_no,
	bank_account_branch,
	ref_order_number,
	ref_order_date
from int_order a
left join group_total g on COALESCE(a.split_order_group, a.unified_sales_order_id) = g.split_key
left join erp_order_payment_entry e on a.haravan_order_id::text = e.haravan_order_id
left join get_sales_info gs on gs.order_id = a.unified_sales_order_id
where 1 = 1
and parentfield = 'payment_entries'
and e.allocated_amount > 0





