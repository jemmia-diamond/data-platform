{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__budget_plan') }}
