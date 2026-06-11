{{ config(
    materialized='incremental',
    unique_key='time_account_key',
    schema='intermediate'
--     post_hook=[
--       "CREATE INDEX IF NOT EXISTS idx_iso_unified_id ON {{ this }} (unified_sales_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_erp_id ON {{ this }} (erp_sales_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_haravan_id ON {{ this }} (haravan_order_id)",
--       "CREATE INDEX IF NOT EXISTS idx_iso_customer_id ON {{ this }} (unified_customer_id)",
--     ]
) }}

select *,
		CASE
	        WHEN LEFT(COALESCE(account_number, ''), 3) = '214'
	        THEN COALESCE(credit_amount, 0)
	        ELSE 0
	    END as taikhoan_214_phatsinh_co,
	    CASE
			WHEN LEFT(account_number, 3) = '331'
			THEN credit_amount::NUMERIC ELSE 0
		END as taikhoan_331_phatsinh_co
from {{ ref('stg_misa__journal_account')}}