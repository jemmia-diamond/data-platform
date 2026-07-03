{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_payment_date ON {{ this }} (payment_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_order_id ON {{ this }} (order_id)"
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
	 -- ===== order identifiers =====
    a.unified_sales_order_id as order_id,
    a.haravan_order_id,
    a.order_number,
    a.erp_sales_order_id,
    a.split_order_group,
    a.split_order_group_name,
    a.haravan_ref_order_id as ref_order_id,
 
    -- ===== order info / dates =====
    a.real_order_date as order_date,
    a.first_order_at,
    a.haravan_created_at::date as haravan_created_date,
    a.haravan_total_price,
    g.group_total_price,
    haravan_customer_id,
	order_customer_type,
    haravan_cancelled_status as cancelled_status,
 
    -- ===== sales channel / branch =====
    gs.city_name as main_branch,
    sales_channel as sales_channel_raw,
    case a.sales_channel
        when 'pos-cua-hang-hn'       then 'POS - Hà Nội'
        when 'pos-cua-hang-hcm'      then 'POS - Hồ Chí Minh'
        when 'pos cua hang can tho'  then 'POS - Cần Thơ'
        when 'pos'                   then 'POS - Chưa xác định'
        when 'staff'                 then 'Nhân viên'
        else 'Kênh online'
    end as sales_channel,
 
    -- ===== payment entry detail =====
    e.payment_date,
    e.allocated_amount,
    e.paid_amount,
    e.payment_order_status,
    e.parentfield,
    mode_of_payment as raw_payment_mode,
    payment_ref as payment_ref,
    case
    	when parentfield = 'payment_entries'
    	and payment_order_status = 'Success'
    	then allocated_amount
    end as total_paid_amount,
 
    -- ===== derived status =====
    case
        when group_total_price <= 0::numeric then 'Không xác định'::text
        when e.allocated_amount >= (group_total_price * 0.3) then 'Đã cọc đủ'::text
        else 'Chưa cọc đủ'::text
    end as deposit_status,
 
    -- ===== bank info =====
    bank,
    bank_account,
    bank_account_no,
    bank_account_branch,
 
    -- ===== reference order info =====
    ref_order_number,
    ref_order_date
from int_order a
left join group_total g on COALESCE(a.split_order_group, a.unified_sales_order_id) = g.split_key
left join erp_order_payment_entry e on a.haravan_order_id::text = e.haravan_order_id
left join get_sales_info gs on gs.order_id = a.unified_sales_order_id










