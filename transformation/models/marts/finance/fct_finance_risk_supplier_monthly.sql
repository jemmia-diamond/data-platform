{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_time_id ON {{ this }} (time_id)"
    ]
) }}

int_misa_risk_supplier_monthly as (
    SELECT
        account_object_name as ncc_name,
        account_number,
        credit_amount,
        posted_date
    FROM {{ ref('int_misa__journal_entries')}}
    WHERE account_number LIKE '331%'
    AND corresponding_account NOT LIKE '331%'
),
misa_risk_supplier_monthly_aggregate as (
    SELECT
		posted_date as time_id,
        ncc_name,
        SUM(credit_amount) AS sum_ncc
    FROM int_misa_risk_supplier_monthly
    GROUP BY 1, 2
),
misa_risk_supplier_monthly_aggregate_rank AS (
    SELECT
        time_id,
        ncc_name,
        sum_ncc,
        RANK() OVER (PARTITION BY time_id ORDER BY sum_ncc DESC) AS rank_ncc,
        SUM(sum_ncc) OVER (PARTITION BY time_id) AS total_month_amount
    FROM misa_risk_supplier_monthly_aggregate
),
fct_misa_risk_supplier as (
	SELECT
	    time_id,
	    SUM(CASE WHEN rank_ncc <= 3 THEN sum_ncc ELSE 0 END) AS sum_credit_top3,
	    MAX(total_month_amount) AS sum_credit_all,
	    ROUND(
	        SUM(CASE WHEN rank_ncc <= 3 THEN sum_ncc ELSE 0 END) /
	        NULLIF(MAX(total_month_amount), 0),
	    4) AS rui_ro_ncc
	FROM misa_risk_supplier_monthly_aggregate_rank
	GROUP BY time_id
)
select *
from fct_misa_risk_supplier