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

-- bảng cân đối
select *,
    CASE WHEN item_code = '100' THEN prev_amount ELSE 0 END AS ma_dau_ky_100,
    CASE WHEN item_code = '100' THEN amount      ELSE 0 END AS ma_cuoi_ky_100,

    CASE WHEN item_code = '130' THEN prev_amount ELSE 0 END AS ma_dau_ky_130,
    CASE WHEN item_code = '130' THEN amount      ELSE 0 END AS ma_cuoi_ky_130,

    CASE WHEN item_code = '140' THEN prev_amount ELSE 0 END AS ma_dau_ky_140,
    CASE WHEN item_code = '140' THEN amount      ELSE 0 END AS ma_cuoi_ky_140,

    CASE WHEN item_code = '300' THEN prev_amount ELSE 0 END AS ma_dau_ky_300,
    CASE WHEN item_code = '300' THEN amount      ELSE 0 END AS ma_cuoi_ky_300,

    CASE WHEN item_code = '310' THEN prev_amount ELSE 0 END AS ma_dau_ky_310,
    CASE WHEN item_code = '310' THEN amount      ELSE 0 END AS ma_cuoi_ky_310,

    CASE WHEN item_code = '311' THEN prev_amount ELSE 0 END AS ma_dau_ky_311,
    CASE WHEN item_code = '311' THEN amount      ELSE 0 END AS ma_cuoi_ky_311,

    CASE WHEN item_code = '400' THEN prev_amount ELSE 0 END AS ma_dau_ky_400,
    CASE WHEN item_code = '400' THEN amount      ELSE 0 END AS ma_cuoi_ky_400
from {{ ref('stg_misa__balance_sheet_monthly_fact') }}