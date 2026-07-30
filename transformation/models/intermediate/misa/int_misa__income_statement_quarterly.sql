{{ config(materialized='ephemeral') }}

select *
from {{ ref('stg_misa__income_statement_quarterly') }}
