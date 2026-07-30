{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ ref('int_misa__balance_sheet_quarterly') }}
