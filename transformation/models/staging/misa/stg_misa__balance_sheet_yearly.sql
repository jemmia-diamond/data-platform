{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'balance_sheet_yearly_fact') }}
