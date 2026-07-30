{{ config(
    materialized='view',
    schema='staging'
) }}

select *
from {{ source('misa', 'budget_plan') }}
