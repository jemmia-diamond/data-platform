{{ config(
    materialized='view',
    schema='staging'
) }}

select
    id,
    "monitorId" as monitor_id,
    "monitorName" as monitor_name,
    date,
    "totalTime" as total_time,
    uptime,
    downtime,
    "uptimePercentage" as uptime_percentage,
    "createdAt" as created_at,
    "updatedAt" as updated_at
from {{ source('tech', 'uptime_reports') }}
