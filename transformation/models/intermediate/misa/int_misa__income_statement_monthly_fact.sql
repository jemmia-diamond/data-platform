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
	CASE WHEN item_code = '11' THEN prev_amount ELSE 0 END AS ma_dau_ky_11,
    CASE WHEN item_code = '11' THEN amount      ELSE 0 END AS ma_cuoi_ky_11,

    CASE WHEN item_code = '10' THEN prev_amount ELSE 0 END AS ma_dau_ky_10,
    CASE WHEN item_code = '10' THEN amount      ELSE 0 END AS ma_cuoi_ky_10,

    CASE WHEN item_code = '21' THEN prev_amount ELSE 0 END AS ma_dau_ky_21,
    CASE WHEN item_code = '21' THEN amount      ELSE 0 END AS ma_cuoi_ky_21,

    CASE WHEN item_code = '31' THEN prev_amount ELSE 0 END AS ma_dau_ky_31,
    CASE WHEN item_code = '31' THEN amount      ELSE 0 END AS ma_cuoi_ky_31,

    CASE WHEN item_code = '20' THEN prev_amount ELSE 0 END AS ma_dau_ky_20,
    CASE WHEN item_code = '20' THEN amount      ELSE 0 END AS ma_cuoi_ky_20,

    CASE WHEN item_code = '25' THEN prev_amount ELSE 0 END AS ma_dau_ky_25,
    CASE WHEN item_code = '25' THEN amount      ELSE 0 END AS ma_cuoi_ky_25,

    CASE WHEN item_code = '26' THEN prev_amount ELSE 0 END AS ma_dau_ky_26,
    CASE WHEN item_code = '26' THEN amount      ELSE 0 END AS ma_cuoi_ky_26,

    CASE WHEN item_code = '60' THEN prev_amount ELSE 0 END AS ma_dau_ky_60,
    CASE WHEN item_code = '60' THEN amount      ELSE 0 END AS ma_cuoi_ky_60

from {{ ref('stg_misa__income_statement_monthly_fact')}}