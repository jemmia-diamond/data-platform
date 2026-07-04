{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_payment_date ON {{ this }} (payment_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_order_id ON {{ this }} (order_id)"
    ]
) }}

select
	 -- ===== order identifiers =====
    order_id,
    haravan_order_id,
    order_number,
    erp_sales_order_id,
    split_order_group,
    split_order_group_name,

    -- ===== order info / dates =====
    first_order_at,
    order_date,
    haravan_total_price,
    group_total_price,
    cancelled_status,

    -- ===== sales channel / branch =====
    main_branch,
    sales_channel,

    -- ===== payment entry detail =====
    payment_date,
    allocated_amount,
    paid_amount,
    payment_order_status,
    parentfield,
    raw_payment_mode,
    payment_ref,

    -- ===== derived status =====
    deposit_status,

    -- ===== bank info =====
    bank,
    bank_account,
    bank_account_no,
    bank_account_branch,

    -- ===== reference order info =====
    ref_order_number,
    ref_order_date,

    -- ===== derived: payment timing check =====
    -- compares payment_date against order_date to flag same-day vs cross-day payments
    case
        when payment_date = order_date then 'Đơn trong ngày'
        when payment_date < order_date then 'Chưa xác định đơn'
        else 'Đơn khác ngày'
    end as payment_period_type
from {{ ref('fct_finance_sales_payment')}}
where 1 = 1
and parentfield = 'payment_entries'
and allocated_amount > 0





