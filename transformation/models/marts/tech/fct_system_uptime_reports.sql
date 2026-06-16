{{ config(
    materialized='materialized_view',
    schema='marts_tech',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_iso_monitor_name ON {{ this }} (monitor_name)",
      "CREATE INDEX IF NOT EXISTS idx_iso_monitor_date ON {{ this }} (date)"
    ]
) }}


with monthly as (
	select
		date_trunc('Month', date)::date as date,
		monitor_name,
		sum(total_time) as total_time,
		sum(uptime) as uptime,
		sum(downtime) as downtime,
		avg(uptime_percentage) as uptime_percentage,
		case
			when sum(uptime)/sum(total_time) >= 0.999 then 'Compliant'
			else 'Breached'
		end as sla_status,
		case
			when sum(uptime)/sum(total_time) >= 0.999 then 'Low'
			when sum(uptime)/sum(total_time) >= 0.99 then 'Medium'
			else 'High'
		end as business_risk_level,
		case
			when avg(uptime_percentage) >= 99.9 then 'Monitor'
			when avg(uptime_percentage) >= 99 then 'Investigate'
			else 'Immediate review'
		end as "action",
		'monthly' as period
	from {{ ref('int_system__uptime_reports')}}
	group by 1,2
),
daily as (
	select
		date,
		monitor_name,
		total_time,
		uptime,
		downtime,
		uptime_percentage,
		case
			when uptime/total_time >= 0.999 then 'Compliant'
			else 'Breached'
		end as sla_status,
		case
			when uptime/total_time >= 0.999 then 'Low'
			when uptime/total_time >= 0.99 then 'Medium'
			else 'High'
		end as business_risk_level,
		case
			when uptime_percentage >= 99.9 then 'Monitor'
			when uptime_percentage >= 99 then 'Investigate'
			else 'Immediate review'
		end as "action",
		'daily' as period
	from {{ ref('int_system__uptime_reports')}}
)
select *
from monthly
union all
select *
from daily
