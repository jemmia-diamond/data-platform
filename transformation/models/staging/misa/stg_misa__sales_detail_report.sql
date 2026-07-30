{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'sales_detail_report') }}
