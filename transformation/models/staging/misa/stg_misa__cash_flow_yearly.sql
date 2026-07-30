{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'cash_flow_yearly_fact') }}
