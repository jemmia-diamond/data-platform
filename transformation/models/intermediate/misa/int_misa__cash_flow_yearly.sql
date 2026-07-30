{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__cash_flow_yearly') }}
