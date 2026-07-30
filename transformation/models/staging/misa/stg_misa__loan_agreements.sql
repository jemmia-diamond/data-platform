{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'loan_agreements') }}
