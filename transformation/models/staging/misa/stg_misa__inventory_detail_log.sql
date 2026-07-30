{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'inventory_detail_log') }}
