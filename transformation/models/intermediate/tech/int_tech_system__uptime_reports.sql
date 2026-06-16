{{ config(
    materialized='incremental',
    unique_key='id',
    schema='intermediate',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_monitor_name ON {{ this }} (monitor_name)",
      "CREATE INDEX IF NOT EXISTS idx_iso_monitor_date ON {{ this }} (date)"
    ]
) }}

select *
from {{ ref('stg_tech_system__uptime_reports')}}