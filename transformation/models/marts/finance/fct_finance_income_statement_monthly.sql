{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_time_id ON {{ this }} (time_id)"
    ]
) }}

select
    time_id,
    SUM(inco.ma_dau_ky_11) AS KQKD_ma_dau_ky_11,
    SUM(inco.ma_cuoi_ky_11) AS KQKD_ma_cuoi_ky_11,
    SUM(inco.ma_dau_ky_10) AS KQKD_ma_dau_ky_10,
    SUM(inco.ma_cuoi_ky_10) AS KQKD_ma_cuoi_ky_10,
    SUM(inco.ma_dau_ky_21) AS KQKD_ma_dau_ky_21,
    SUM(inco.ma_cuoi_ky_21) AS KQKD_ma_cuoi_ky_21,
    SUM(inco.ma_dau_ky_31) AS KQKD_ma_dau_ky_31,
    SUM(inco.ma_cuoi_ky_31) AS KQKD_ma_cuoi_ky_31,
    SUM(inco.ma_dau_ky_20) AS KQKD_ma_dau_ky_20,
    SUM(inco.ma_cuoi_ky_20) AS KQKD_ma_cuoi_ky_20,
    SUM(inco.ma_dau_ky_25) AS KQKD_ma_dau_ky_25,
    SUM(inco.ma_cuoi_ky_25) AS KQKD_ma_cuoi_ky_25,
    SUM(inco.ma_dau_ky_26) AS KQKD_ma_dau_ky_26,
    SUM(inco.ma_cuoi_ky_26) AS KQKD_ma_cuoi_ky_26,
    SUM(inco.ma_dau_ky_60) AS KQKD_ma_dau_ky_60,
    SUM(inco.ma_cuoi_ky_60) AS KQKD_ma_cuoi_ky_60
from {{ ref('int_misa__income_statement_monthly_fact')}} inco
group by 1