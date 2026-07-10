{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_report_date ON {{ this }} (report_date)"
    ]
) }}

select *
from {{ ref('int_inventory__stock_by_location_daily_snapshot') }}