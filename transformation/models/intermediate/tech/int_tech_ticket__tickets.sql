{{ config(
    materialized='incremental',
    unique_key='ticket_id',
    schema='intermediate',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_ticket_id ON {{ this }} (ticket_id)",
      "CREATE INDEX IF NOT EXISTS idx_iso_created_date ON {{ this }} (created_date)"
    ]
) }}

with int_ticket as (
    select *
    from {{ ref('stg_larksuite_ticket__tickets')}}
),
ticket_normalized_status_priority as (
    select
        record_id,
        created_time::date as created_date,
        ticket_id,
        ticket_name,
        ticket_type,
        ticket_priority,
        case
            when trim(lower(ticket_priority)) like '%gấp%' then 'Critical'
            when trim(lower(ticket_priority)) like '%cần sớm%' then 'High'
            when trim(lower(ticket_priority)) like '%bình thường%' then 'Medium'
            when ticket_priority like 'Ảnh Hưởng Đến Công Việc Trong Tuần' then 'Medium'
            when trim(lower(ticket_priority)) like '%có thể chờ sau%' then 'Low'
            else 'Unknown'
        end as ticket_priority_normalized,
        ticket_status,
        case
            when lower(ticket_status) like '%ticket mới%' then 'New'
            when lower(ticket_status) like '%ticket mới%' then 'New'

            when ticket_status like '%2️⃣ Đã Tiếp Nhận%' then 'Accepted'
            when lower(ticket_status) like '%chờ xử lý%' then 'Accepted'

            when ticket_status like '%3️⃣ Đang xử lý%' then 'In Progress'

            when ticket_status like '%4️⃣ Đang review%' then 'In Review'

            when lower(ticket_status) like '%chờ phản hồi%' then 'Waiting Response'

            when lower(ticket_status) like '%on hold%' then 'On Hold'

            when lower(ticket_status) like '%đã hoàn thành%' then 'Closed'
            when lower(ticket_status) like '%closed%' then 'Closed'

            when lower(ticket_status) like '%đã hủy%' then 'Cancelled'
            when lower(ticket_status) like '%cancelled%' then 'Cancelled'

            else 'Unknown'
        end as ticket_status_normalized,
        description,
        solution_update,
        created_time,
        updated_time,
        manual_updated_time,
        completed_time,
        expected_completion_time,
        ticket_no_in_month,
        current_number_in_month,
        synced_at,
        manager,
        new_deadline,
        reminder_time,
        sla_50_percent,
        completed_at,
        processed_at,
        responded_at
    from int_ticket
)
select *,
    case
        when ticket_status_normalized = 'Closed'
        then extract(epoch from (new_deadline - completed_time)) / 3600.0
    end as resolve_hour
from ticket_normalized_status_priority