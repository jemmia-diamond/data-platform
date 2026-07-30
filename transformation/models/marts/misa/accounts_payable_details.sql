{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ ref('int_misa__accounts_payable_details') }}
