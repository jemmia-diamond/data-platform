{{ config(
    materialized='materialized_view',
    schema='marts_finance',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsi_order_number ON {{ this }} (order_number)",
      "CREATE INDEX IF NOT EXISTS idx_fsi_split_order_group ON {{ this }} (split_order_group)"
    ]
) }}

select *
from {{ ref('int_finance__receivable_item_status')}}