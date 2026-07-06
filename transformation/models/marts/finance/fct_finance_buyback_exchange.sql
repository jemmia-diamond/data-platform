{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_submitted_date ON {{ this }} (submitted_date)"
    ]
) }}

select *
from {{ ref('int_buyback__exchange_details')}}