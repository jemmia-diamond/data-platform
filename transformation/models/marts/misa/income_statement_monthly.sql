{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ source('misa', 'income_statement_monthly_fact') }}
