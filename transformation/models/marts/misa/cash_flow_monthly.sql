{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ source('misa', 'cash_flow_monthly_fact') }}
