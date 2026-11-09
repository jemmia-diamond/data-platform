{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsaos_appointment_id ON {{ this }} (appointment_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsaos_sales_person_id ON {{ this }} (appointment_sales_person_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsaos_scheduled_date ON {{ this }} (scheduled_date)",
    ]
) }}

with appointment_order as (
    select * from {{ ref('fct_sales_appointment_order') }}
),

-- revenue split between sales persons (Appointment Sales Split child table in ERPNext).
-- percentage is the source of truth (commission_amount can go stale), one sales person can
-- have several rows. Ratios are normalized by the appointment's total percentage so the
-- shares always add back up to the full order_revenue.
appointment_sales_splits as (
    select
        appointment_id,
        sales_person_id,
        sum(percentage) as percentage
    from {{ ref('stg_erpnext__appointment_sales_splits') }}
    where sales_person_id is not null
        and percentage > 0
    group by 1, 2
),

split_totals as (
    select
        appointment_id,
        sum(percentage) as total_percentage
    from appointment_sales_splits
    group by 1
),

-- 1 row per appointment x credited sales person.
-- no split rows -> the appointment's primary sales person gets 100%.
appointment_sales as (
    select
        ao.appointment_id,
        coalesce(s.sales_person_id, ao.appointment_sales_person_id) as sales_person_id,
        coalesce(s.percentage / t.total_percentage, 1) as split_ratio,
        (s.appointment_id is not null) as is_split
    from appointment_order ao
    left join split_totals t
        on t.appointment_id = ao.appointment_id
    left join appointment_sales_splits s
        on s.appointment_id = t.appointment_id
)

select
    ao.appointment_id || ':' || coalesce(asl.sales_person_id, '') as appointment_sales_key,
    ao.appointment_id,
    ao.lead_id,
    ao.party_id,
    ao.erp_sales_order_id,
    ao.appointment_with,
    ao.appointment_with_display,
    ao.appointment_reason,
    ao.notes,
    ao.order_status,
    ao.budget,
    ao.created_at_vn,
    ao.updated_at,
    ao.updated_at_vn,
    ao.resolved_lead_id,
    ao.scheduled_date,
    ao.scheduled_time,
    -- the credited sales person: the split sales person, or the primary sales when not split
    asl.sales_person_id as appointment_sales_person_id,
    case
        when asl.sales_person_id = ao.appointment_sales_person_id then ao.appointment_sales_person_name
        else dsp.sales_person_name
    end as appointment_sales_person_name,
    case
        when asl.sales_person_id = ao.appointment_sales_person_id then ao.appointment_sales_person_position
        else dsp.sales_position
    end as appointment_sales_person_position,
    asl.is_split,
    round(asl.split_ratio * 100, 2) as split_percentage,
    ao.status,
    ao.status_display,
    ao.at_store_transformed,
    ao.has_order,
    ao.order_date,
    ao.order_number,
    ao.order_id,
    ao.order_sales_position,
    ao.order_revenue * asl.split_ratio as order_revenue,
    ao.order_revenue as order_group_revenue,
    ao.order_group
from appointment_order ao
inner join appointment_sales asl on asl.appointment_id = ao.appointment_id
left join {{ ref('dim_sales_persons') }} dsp on dsp.sales_person_id = asl.sales_person_id
