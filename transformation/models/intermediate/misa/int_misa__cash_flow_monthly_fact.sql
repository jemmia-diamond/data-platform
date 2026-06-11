{{ config(
    materialized='incremental',
    unique_key='time_item_key',
    schema='intermediate'
) }}

select *,
	CASE WHEN item_code = '20' THEN prev_amount ELSE 0 END AS ma_dau_ky_20,
    CASE WHEN item_code = '20' THEN amount      ELSE 0 END AS ma_cuoi_ky_20
from {{ ref('stg_misa__cash_flow_monthly_fact')}}