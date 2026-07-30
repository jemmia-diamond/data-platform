{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__balance_sheet_quarterly') }}
