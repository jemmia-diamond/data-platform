{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsao_appointment_id ON {{ this }} (appointment_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsao_party_id ON {{ this }} (party_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsao_order_date ON {{ this }} (order_date)",
    ]
) }}

with appointments as (
    select
        a.appointment_id,
        a.lead_id,
        a.party_id,
        a.appointment_with,
        a.appointment_reason,
        a.scheduled_date,
        a.scheduled_time_vn,
        a.at_store,
        a.sales_person_id,
        a.sales_person_name,
        a.status,
        -- party_id can be a Lead (new lead booking) or a Customer (existing customer booking a
        -- repeat appointment) depending on appointment_with. fct_sales_leads_orders is keyed on
        -- lead_id_unified, so for the Customer case resolve back to the originating lead first.
        coalesce(
            case when a.appointment_with = 'Lead' then a.party_id end,
            dc.lead_name
        ) as resolved_lead_id
    from {{ ref('fct_sales_appointments') }} a
    left join {{ ref('dim_sales_customers') }} dc
        on dc.customer_id = a.party_id
        and a.appointment_with != 'Lead'
),

-- pre-aggregate every online order down to 1 row per (lead, order_date) ONCE for the whole
-- table, instead of re-running this GROUP BY inside a correlated subquery for every appointment.
-- Orders in the same checkout group split across multiple order_number rows on the same
-- order_date are collapsed here.
lead_order_dates as (
    select
        lo.lead_id_unified,
        lo.order_date,
        string_agg(distinct lo.lead_name_has_order_number, ', ') as order_number,
        string_agg(distinct fso.order_id, ', ') as order_id,
        sum(lo.total_price_lead_name_has_order) as order_revenue
    from {{ ref('fct_sales_leads_orders') }} lo
    left join {{ ref('fct_sales_orders') }} fso
        on fso.order_number = lo.lead_name_has_order_number
    where lo.lead_name_has_order_group is not null
    and lo.sales_position like '%Sale Online%'
    group by lo.lead_id_unified, lo.order_date
),

appointment_order as (
    select
        ap.*,
        fo.order_date as first_order_date,
        fo.order_number as first_order_number,
        fo.order_id as first_order_id,
        fo.order_revenue as first_order_revenue
    from appointments ap
    left join lateral (
        -- earliest pre-aggregated order date on/after the appointment for this lead
        select lod.order_date, lod.order_number, lod.order_id, lod.order_revenue
        from lead_order_dates lod
        where lod.lead_id_unified = ap.resolved_lead_id
        and lod.order_date >= ap.scheduled_date
        order by lod.order_date asc
        limit 1
    ) fo on ap.resolved_lead_id is not null
)

select
    appointment_id,
    lead_id,
    party_id,
    appointment_with,
    case
        when appointment_with = 'Customer' then 'Khách cũ'
        else 'Khách mới'
    end as appointment_with_display,
    appointment_reason,
    resolved_lead_id,
    scheduled_date,
    sales_person_id,
    sales_person_name,
    status,
    case
        when status = 'Done' then 'Hoàn thành'
        when status = 'Cancelled' then 'Hủy'
        when status = 'Open' and scheduled_time_vn < (now() at time zone 'Asia/Ho_Chi_Minh') then 'Quá hạn'
        when status = 'Open' then 'Đang chờ'
    end as status_display,
    case
        when at_store like '%Cần Thơ%' then 'Cần Thơ'
        when at_store like '%Hà Nội%' then 'Hà Nội'
        when at_store like '%Hồ Chí Minh%' then 'Hồ Chí Minh'
    end as at_store_transformed,
    (first_order_date is not null) as has_order,
    first_order_date as order_date,
    first_order_number as order_number,
    first_order_id as order_id,
    coalesce(first_order_revenue, 0) as order_revenue
from appointment_order
