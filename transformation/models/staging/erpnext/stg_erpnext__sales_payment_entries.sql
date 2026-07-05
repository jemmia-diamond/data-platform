{{ config(
    materialized='view',
    schema='staging'
) }}

with payment_entry as (
    select
        haravan_order_id,
        entry.value as entry_json
    from {{ ref('stg_erpnext__sales_orders')}} so
    left join lateral jsonb_array_elements(so.payment_entry_references) as entry(value) on true 
    where jsonb_typeof(so.payment_entry_references) = 'array'

),
-- Grain: 1 row = 1 payment entry (unnested from the `payment_entries` jsonb array on the raw sales order)
parse_payment_entry as (
    select
        -- ==== key =====
        haravan_order_id,

        -- ===== identifiers / linking fields =====
        nullif(entry_json->>'parent', '') as parent_order_id,
        nullif(entry_json->>'parentfield', '') as parentfield,
        nullif(entry_json->>'parenttype', '')  as parenttype,
        (entry_json->>'idx')::int  as idx,
        nullif(entry_json->>'reference_name', '') as payment_ref,       -- Payment Entry code (ACC-PAY-...)
        nullif(entry_json->>'reference_doctype', '') as reference_doctype,
        nullif(entry_json->>'split_order_group_name', '') as payment_entry_split_order_group_name,

        -- ===== status =====
        nullif(entry_json->>'payment_order_status', '') as payment_order_status,
        (entry_json->>'docstatus')::int   as docstatus,

        -- ===== amounts =====
        (entry_json->>'paid_amount')::numeric  as paid_amount,
        (entry_json->>'allocated_amount')::numeric as allocated_amount,
        (entry_json->>'unallocated_amount')::numeric  as unallocated_amount,
        (entry_json->>'total_amount')::numeric  as total_amount,
        (entry_json->>'outstanding_amount')::numeric   as outstanding_amount,
        (entry_json->>'payment_term_outstanding')::numeric  as payment_term_outstanding,
        (entry_json->>'exchange_rate')::numeric  as exchange_rate,
        (entry_json->>'exchange_gain_loss')::numeric   as exchange_gain_loss,
        (entry_json->>'balance')::numeric   as balance,

        -- ===== payment details =====
        nullif(entry_json->>'mode_of_payment', '') as mode_of_payment,
        nullif(entry_json->>'payment_type', '') as payment_type,
        nullif(entry_json->>'gateway', '') as gateway,
        nullif(entry_json->>'bank', '')    as bank,
        nullif(entry_json->>'bank_account', '') as bank_account,
        nullif(entry_json->>'bank_account_no', '') as bank_account_no,
        nullif(entry_json->>'bank_account_branch', '')   as bank_account_branch,
        nullif(entry_json->>'account', '') as account,
        nullif(entry_json->>'account_type', '') as account_type,

        -- ===== advance / payment request (for deposits / installment plans) =====
        nullif(entry_json->>'advance_voucher_no', '') as advance_voucher_no,
        nullif(entry_json->>'advance_voucher_type', '')  as advance_voucher_type,
        nullif(entry_json->>'payment_request', '') as payment_request,
        nullif(entry_json->>'payment_term', '') as payment_term,
        coalesce(entry_json->>'order_number', '') as payment_entry_order_number,
        coalesce(entry_json->>'ref_order_number', '')   as ref_order_number,
        nullif(entry_json->>'bill_no', '') as bill_no,
        nullif(entry_json->>'reconcile_effect_on', '')   as reconcile_effect_on,

        -- ===== timestamps =====
        (entry_json->>'payment_date')::date   as payment_date,
        (entry_json->>'due_date')::date    as due_date,
        (entry_json->>'ref_order_date')::date as ref_order_date,
        (entry_json->>'creation')::timestamp    as _entry_created_at,
        (entry_json->>'modified')::timestamp    as _entry_modified_at,
        nullif(entry_json->>'modified_by', '')  as _entry_modified_by,
        nullif(entry_json->>'owner', '')   as _entry_owner
    from payment_entry
)
select *
from parse_payment_entry



