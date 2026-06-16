{{ config(
    materialized='view',
    schema='staging'
) }}

select
	record_id,
	created_time::date as created_date,
	ticket_id,
	ticket_name,
	ticket_type,
	ticket_priority,
	ticket_status,
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
from {{ source('larksuite', 'tickets') }}
