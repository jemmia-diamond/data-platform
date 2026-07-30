{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__sales_detail_report') }}
