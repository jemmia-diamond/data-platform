{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__loan_agreements') }}
