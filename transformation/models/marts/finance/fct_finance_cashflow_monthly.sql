{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_time_id ON {{ this }} (time_id)"
    ]
) }}

select
    time_id,
    sum(cash.ma_dau_ky_20) as LCTT_ma_dau_ky_20,
    sum(cash.ma_cuoi_ky_20) as LCTT_ma_cuoi_ky_20
from {{ ref('int_misa__cash_flow_monthly_fact')}} cash
group by 1