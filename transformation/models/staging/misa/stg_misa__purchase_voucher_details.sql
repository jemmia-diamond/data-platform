{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'purchase_voucher_details') }}
