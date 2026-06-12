{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_time_id ON {{ this }} (time_id)"
    ]
) }}

select
    time_id,
    SUM(bal.ma_dau_ky_100) AS CDKT_ma_dau_ky_100,
    SUM(bal.ma_cuoi_ky_100) AS CDKT_ma_cuoi_ky_100,
    SUM(bal.ma_dau_ky_130) AS CDKT_ma_dau_ky_130,
    SUM(bal.ma_cuoi_ky_130) AS CDKT_ma_cuoi_ky_130,
    SUM(bal.ma_dau_ky_140) AS CDKT_ma_dau_ky_140,
    SUM(bal.ma_cuoi_ky_140) AS CDKT_ma_cuoi_ky_140,
    SUM(bal.ma_dau_ky_300) AS CDKT_ma_dau_ky_300,
    SUM(bal.ma_cuoi_ky_300) AS CDKT_ma_cuoi_ky_300,
    SUM(bal.ma_dau_ky_310) AS CDKT_ma_dau_ky_310,
    SUM(bal.ma_cuoi_ky_310) AS CDKT_ma_cuoi_ky_310,
    SUM(bal.ma_dau_ky_311) AS CDKT_ma_dau_ky_311,
    SUM(bal.ma_cuoi_ky_311) AS CDKT_ma_cuoi_ky_311,
    SUM(bal.ma_dau_ky_400) AS CDKT_ma_dau_ky_400,
    SUM(bal.ma_cuoi_ky_400) AS CDKT_ma_cuoi_ky_400
from {{ ref('int_misa__balance_sheet_monthly_fact')}} bal
group by 1