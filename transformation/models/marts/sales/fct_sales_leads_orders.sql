{{ config(
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
		lead_status,
		lead_stage,
        consultation_date_range,
        time_to_convert_hours,
        -- unified qualified flag: pre-2026-08-01 process flagged via qualification_status_raw,
        -- post-2026-08-01 process flags via lead_status instead (qualification_status_raw is being retired)
        (qualification_status_raw = 'Qualified' OR lead_status IN ('Qualified', 'Converted')) AS is_qualified_unified
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
		lead_status,
		lead_stage,
        consultation_date_range,
        time_to_convert_hours,
        (qualification_status_raw = 'Qualified' OR lead_status IN ('Qualified', 'Converted')) AS is_qualified_unified,
		case when (qualification_status_raw = 'Qualified' OR lead_status IN ('Qualified', 'Converted')) then lead_id end as qualified_lead_id,
		CASE
		    WHEN DATE_TRUNC('month', lead_entry_date)
		       <> DATE_TRUNC('month', converted_date)
		       and (qualification_status_raw = 'Qualified' OR lead_status IN ('Qualified', 'Converted'))
		    THEN lead_id
		END as qualified_lead_id_not_in_month,
		CASE
		    WHEN DATE_TRUNC('month', lead_entry_date)
		       = DATE_TRUNC('month', converted_date)
		       and (qualification_status_raw = 'Qualified' OR lead_status IN ('Qualified', 'Converted'))
		    THEN lead_id
		END as qualified_lead_id_in_month
	from lead_data q
	where 1 = 1
),
lead_join_qualified as (
	select
		GREATEST(l.lead_entry_date, q.converted_date) AS date,
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
	    COALESCE(l.lead_status, q.lead_status) AS lead_status,
	    COALESCE(l.lead_stage, q.lead_stage) AS lead_stage,
	    COALESCE(l.consultation_date_range, q.consultation_date_range) AS consultation_date_range,
        COALESCE(l.time_to_convert_hours, q.time_to_convert_hours) as time_to_convert_hours,
	    COALESCE(l.is_qualified_unified, q.is_qualified_unified)::int as is_qualified_unified,
	    q.qualified_lead_id,
	    q.qualified_lead_id_not_in_month,
	    q.qualified_lead_id_in_month,
		case
			when l.lead_entry_date = l.converted_date
			and l.is_qualified_unified
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
opportunities_ranked as (
    select
        *,
        row_number() over (
            partition by party_name
            order by opportunity_date desc
        ) as rn
    from {{ ref('int_crm__opportunities') }}
),
latest_opportunity as (
    -- most recent opportunity per lead (opportunities are sequential attempts, never concurrent)
    select
        party_name as lead_id,
        opportunity_id,
        status as opportunity_status,
        sales_stage as opportunity_sales_stage,
        probability as opportunity_probability,
        opportunity_amount,
        opportunity_date
    from opportunities_ranked
    where rn = 1
),
lead_notes as (
    select
        parent_id as lead_id,
        string_agg(
            COALESCE(note_type, 'Note') || ': ' || regexp_replace(COALESCE(note_content, ''), '<[^>]+>', '', 'g'),
            E'\n' order by added_on
        ) as lead_stage_note
    from {{ ref('int_crm__notes') }}
    where parent_type = 'Lead'
    group by parent_id
),
opp_notes as (
    select
        parent_id as opportunity_id,
        string_agg(
            COALESCE(note_type, 'Note') || ': ' || regexp_replace(COALESCE(note_content, ''), '<[^>]+>', '', 'g'),
            E'\n' order by added_on
        ) as opp_stage_note
    from {{ ref('int_crm__notes') }}
    where parent_type = 'Opportunity'
    group by parent_id
),
lead_sales as (
	select
		l.*,
        s.order_date,
        s.split_order_group as lead_name_has_order_group,
        s.order_number as lead_name_has_order_number,
        s.allocated_total_price_by_order_id as total_price_lead_name_has_order,
        lo.opportunity_id,
        lo.opportunity_status,
        lo.opportunity_sales_stage,
        lo.opportunity_probability,
        lo.opportunity_amount,
        lo.opportunity_date,
        ln.lead_stage_note,
        opn.opp_stage_note
	from lead_join_qualified l
	left join sales s
        on l.date <= s.order_date and l.lead_id_unified = s.lead_name
    left join latest_opportunity lo
        on l.lead_id_unified = lo.lead_id
    left join lead_notes ln
        on l.lead_id_unified = ln.lead_id
    left join opp_notes opn
        on lo.opportunity_id = opn.opportunity_id
)
select *
from lead_sales