{{ config(
    materialized='incremental',
    unique_key='record_id',
    schema='intermediate',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_record_id ON {{ this }} (record_id)",
      "CREATE INDEX IF NOT EXISTS idx_iso_created_date ON {{ this }} (created_date)"
    ]
) }}

with ticket_add_created_time_bh as (
    select *,
    	CASE
          WHEN created_time IS NULL THEN NULL
          WHEN EXTRACT(ISODOW FROM created_time) = 6 THEN date_trunc('day', created_time) + interval '2 day 9 hour'
          WHEN EXTRACT(ISODOW FROM created_time) = 7 THEN date_trunc('day', created_time) + interval '1 day 9 hour'
          WHEN created_time::time < time '09:00' THEN date_trunc('day', created_time) + interval '9 hour'
          WHEN created_time::time >= time '12:30' AND created_time::time < time '13:30' THEN date_trunc('day', created_time) + interval '13 hour 30 minute'
          WHEN created_time::time >= time '18:00' AND EXTRACT(ISODOW FROM created_time) = 5 THEN date_trunc('day', created_time) + interval '3 day 9 hour'
          WHEN created_time::time >= time '18:00' THEN date_trunc('day', created_time) + interval '1 day 9 hour'
          ELSE created_time
        END AS created_time_bh
    from {{ ref('stg_larksuite_ticket__tickets')}}
),
ticket_add_time_fixed as (
	select *,
		GREATEST(COALESCE(responded_at, created_time_bh), created_time_bh) AS responded_at_fixed,
		GREATEST(COALESCE(processed_at, created_time_bh), created_time_bh) AS processed_at_fixed,
		COALESCE(completed_at, completed_time) AS completed_time_raw,
		GREATEST(COALESCE(completed_at, completed_time, created_time_bh), created_time_bh) AS completed_time_fixed
	from ticket_add_created_time_bh
),
ticket_add_resolve_minute as (
	select *,
		CASE
			WHEN completed_time_fixed <= created_time_bh THEN 0
		    ELSE (
		        SELECT COALESCE(SUM(
		          GREATEST(EXTRACT(EPOCH FROM (
		            LEAST(date_trunc('day', gs) + interval '12 hour 30 minute', completed_time_fixed)
		            - GREATEST(date_trunc('day', gs) + interval '9 hour', created_time_bh)
		          )) / 60, 0)
		          +
		          GREATEST(EXTRACT(EPOCH FROM (
		            LEAST(date_trunc('day', gs) + interval '18 hour', completed_time_fixed)
		            - GREATEST(date_trunc('day', gs) + interval '13 hour 30 minute', created_time_bh)
		          )) / 60, 0)
		        ), 0)::int
		        FROM generate_series(
		          date_trunc('day', created_time_bh),
		          date_trunc('day', completed_time_fixed),
		          interval '1 day'
		        ) gs
		        WHERE EXTRACT(ISODOW FROM gs) BETWEEN 1 AND 5
		      )/60
		    END AS resolve_hours
    from ticket_add_time_fixed
),
ticket_normalized_status_priority as (
    select
        record_id,
        created_time_bh::date as created_date,
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
            -- for special character --> need to add this duplicate
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
        responded_at,
        resolve_hours,
        created_time_bh
    from ticket_add_resolve_minute
)
select *
from ticket_normalized_status_priority

