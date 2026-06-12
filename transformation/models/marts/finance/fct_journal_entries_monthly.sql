{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_time_id ON {{ this }} (time_id)"
    ]
) }}

with int_misa_journal_entries as (
	select *
	from {{ ref('int_misa__journal_entries')}}
),
journal_entries_monthly as (
    select *,
        posted_date as time_id,
        CASE
            WHEN LEFT(COALESCE(account_number, ''), 3) = '214'
            THEN COALESCE(credit_amount, 0)
            ELSE 0
        END as NKC_taikhoan_214_phatsinh_co,
        CASE
            WHEN LEFT(account_number, 3) = '331'
            THEN credit_amount::NUMERIC ELSE 0
        END as NKC_taikhoan_331_phatsinh_co
    from int_misa_journal_entries
)
select
    time_id,
    sum(NKC_taikhoan_214_phatsinh_co) as NKC_taikhoan_214_phatsinh_co,
    sum(NKC_taikhoan_331_phatsinh_co) as NKC_taikhoan_331_phatsinh_co
from journal_entries_monthly
