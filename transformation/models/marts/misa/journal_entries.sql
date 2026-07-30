{{ config(
    materialized='view',
    schema='marts_misa'
) }}

select *
from {{ source('misa', 'journal_entries') }}
