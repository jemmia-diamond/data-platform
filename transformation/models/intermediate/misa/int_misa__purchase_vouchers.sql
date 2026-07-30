{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__purchase_vouchers') }}
