{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'income_statement_quarterly_fact') }}
