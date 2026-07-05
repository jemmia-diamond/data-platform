{{ config(
    materialized='incremental',
    unique_key='haravan_order_id',
    schema='intermediate',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_haravan_order_id ON {{ this }} (haravan_order_id)",
      "CREATE INDEX IF NOT EXISTS idx_iso_payment_date ON {{ this }} (payment_date)"
    ]
) }}

select *
from {{ ref('stg_erpnext__sales_payment_entries')}}