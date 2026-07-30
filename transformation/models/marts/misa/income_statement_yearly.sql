{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ ref('int_misa__income_statement_yearly') }}
