{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'pending_loan_agreements') }}
