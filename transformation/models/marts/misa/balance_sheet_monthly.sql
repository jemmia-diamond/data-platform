{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ source('misa', 'balance_sheet_monthly_fact') }}
