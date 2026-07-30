{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__pending_loan_agreements') }}
