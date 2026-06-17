{{ config(
    materialized='view',
    schema='staging'
) }}

select
	record_id,
    ticket_id,
    ticket_name,
    ticket_type,
    ticket_priority,
    ticket_status,
    description,
    solution_update,
    ((created_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as created_time,
    ((updated_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as updated_time,
    ((manual_updated_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as manual_updated_time,
    ((completed_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as completed_time,
    ((expected_completion_time AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as expected_completion_time,
    ticket_no_in_month,
    current_number_in_month,
    synced_at,
    manager,
    new_deadline,
    reminder_time,
    sla_50_percent,
    ((completed_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as completed_at,
    ((processed_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as processed_at,
    ((responded_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh') as responded_at
from {{ source('larksuite', 'tech_tickets') }}

