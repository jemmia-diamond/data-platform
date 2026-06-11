{{ config(
    materialized='incremental',
    unique_key='time_account_key',
    schema='intermediate'
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
from {{ ref('stg_misa__journal_entries')}}