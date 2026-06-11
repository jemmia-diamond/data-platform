{{ config(
    materialized='incremental',
    unique_key='time_item_key',
    schema='intermediate'
--     post_hook=[
--       "CREATE INDEX IF NOT EXISTS idx_iso_unified_id ON {{ this }} (unified_sales_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_erp_id ON {{ this }} (erp_sales_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_haravan_id ON {{ this }} (haravan_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_customer_id ON {{ this }} (unified_customer_id)",
--     ]
) }}

select *,
	CASE WHEN item_code = '20' THEN prev_amount ELSE 0 END AS ma_dau_ky_20,
    CASE WHEN item_code = '20' THEN amount      ELSE 0 END AS ma_cuoi_ky_20
from {{ ref('stg_misa__cash_flow_monthly_fact')}}