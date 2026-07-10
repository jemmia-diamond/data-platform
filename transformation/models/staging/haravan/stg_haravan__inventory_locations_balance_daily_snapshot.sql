{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('haravan', 'inventory_locations_balance_daily_snapshot') }}