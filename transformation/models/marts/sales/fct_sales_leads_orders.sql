{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsl_date ON {{ this }} USING brin (date)",
      "CREATE INDEX IF NOT EXISTS idx_fsl_lead_source_name ON {{ this }} (lead_source_name)",
    ]
) }}

with
lead_data as (
    select *,
        CASE
            WHEN (converted_date - lead_entry_date) <= 7 THEN '7 Ngày'
            WHEN (converted_date - lead_entry_date) <= 14 THEN '14 Ngày'
            WHEN (converted_date - lead_entry_date) <= 30 THEN '30 ngày'
            WHEN (converted_date - lead_entry_date) <= 60 THEN '60 ngày'
            WHEN (converted_date - lead_entry_date) <= 90 THEN '90 ngày'
            WHEN (converted_date - lead_entry_date) > 90 THEN 'trên 90'
            ELSE 'Chưa xác định'
        END AS consultation_date_range
    from {{ ref('fct_sales_leads')}}
),
lead_source as (
	select
		lead_entry_date,
		lead_id,
		converted_date,
		qualification_status_raw,
		sales_region,
		region,
		budget_label,
		lead_owner,
		lead_source_name,
		lead_source_platform,
		demand_label,
		gender,
        consultation_date_range
	from lead_data l
	where 1 = 1
),
qualified_lead_source as (
	select
		lead_entry_date,
		lead_id,
		converted_date,
		qualification_status_raw,
		sales_region,
		region,
		budget_label,
		lead_owner,
		lead_source_name,
		lead_source_platform,
		demand_label,
		gender,
        consultation_date_range,
		case when qualification_status_raw = 'Qualified' then lead_id end as qualified_lead_id,
		CASE
		    WHEN DATE_TRUNC('month', lead_entry_date)
		       <> DATE_TRUNC('month', converted_date)
		       and qualification_status_raw = 'Qualified'
		    THEN lead_id
		END as qualified_lead_id_not_in_month,
		CASE
		    WHEN DATE_TRUNC('month', lead_entry_date)
		       = DATE_TRUNC('month', converted_date)
		       and qualification_status_raw = 'Qualified'
		    THEN lead_id
		END as qualified_lead_id_in_month
	from lead_data q
	where 1 = 1
),
lead_join_qualified as (
	select
		COALESCE(l.lead_entry_date, q.converted_date) AS date,
		coalesce(l.lead_entry_date, q.lead_entry_date) as lead_entry_date,
		coalesce(l.converted_date, q.converted_date) as converted_date,
		coalesce(l.qualification_status_raw, q.qualification_status_raw) as qualification_status_raw,
		coalesce(l.lead_id, q.lead_id) as lead_id_unified,
	    l.lead_id as l_lead_id,
	    q.lead_id as q_lead_id,
	    COALESCE(l.sales_region, q.sales_region) AS sales_region,
	    COALESCE(l.region, q.region) AS region,
	    COALESCE(l.budget_label, q.budget_label) AS budget_label,
	    COALESCE(l.lead_owner, q.lead_owner) AS lead_owner,
	    COALESCE(l.lead_source_name, q.lead_source_name) AS lead_source_name,
	    COALESCE(l.lead_source_platform, q.lead_source_platform) AS lead_source_platform,
	    COALESCE(l.demand_label, q.demand_label) AS demand_label,
	    COALESCE(l.gender, q.gender) AS gender,
	    COALESCE(l.consultation_date_range, q.consultation_date_range) AS consultation_date_range,
	    q.qualified_lead_id,
	    q.qualified_lead_id_not_in_month,
	    q.qualified_lead_id_in_month,
		case
			when l.lead_entry_date = l.converted_date
			and l.qualification_status_raw = 'Qualified'
			then qualified_lead_id
		end as qualified_lead_id_in_day
	from lead_source l
	full join qualified_lead_source q on l.lead_id = q.lead_id
),
sales as (
	select
		s.*
	from {{ ref('fct_sales_order_all_metrics')}} s
	where 1 = 1
),
lead_sales as (
	select
		l.*,
		s.product_name
	from lead_join_qualified l
	left join sales s on l.lead_id_unified = s.lead_name
)
select *
from lead_sales