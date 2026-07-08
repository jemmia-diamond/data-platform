{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('erpnext', 'buyback_exchange_items') }}