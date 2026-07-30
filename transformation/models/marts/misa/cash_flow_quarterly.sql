{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ ref('int_misa__cash_flow_quarterly') }}
