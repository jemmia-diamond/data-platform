{{ config(
    materialized='materialized_view',
    schema='marts_tech',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_record_id ON {{ this }} (record_id)",
      "CREATE INDEX IF NOT EXISTS idx_iso_created_date ON {{ this }} (created_date)"
    ]
) }}

select *,
    case
        when ticket_status_normalized = 'Closed' then record_id
    end as ticket_completed,
    -- critical priority
    case 
        when ticket_priority_normalized in ('Critical')
        and ticket_status_normalized = 'Closed'
        and resolve_hours <= 5 then 1
        else 0
    end as critital_ticket_completed_in_5_hours,
    case
        when ticket_priority_normalized in ('Critical')
        and ticket_status_normalized = 'Closed'
         then 1
        else 0
    end as critital_ticket_completed,
    -- high priority
    case
        when ticket_priority_normalized in ('High')
        and ticket_status_normalized = 'Closed'
        and resolve_hours <= 16 then 1
        else 0
    end as high_ticket_completed_in_16_hours,
    case
        when ticket_priority_normalized in ('High')
        and ticket_status_normalized = 'Closed'
        then 1
        else 0
    end as high_ticket_completed,
    -- medium priority
    case
        when ticket_priority_normalized in ('Medium')
        and ticket_status_normalized = 'Closed'
        and resolve_hours <= 40 then 1
        else 0
    end as medium_ticket_completed_in_40_hours,
    case
        when ticket_priority_normalized in ('Medium')
        and ticket_status_normalized = 'Closed'
        then 1
        else 0
    end as medium_ticket_completed
from {{ ref('int_tech_ticket__tickets')}}
