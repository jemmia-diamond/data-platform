{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'accounts_payable_details') }}
