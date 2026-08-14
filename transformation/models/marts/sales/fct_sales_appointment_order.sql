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
        a.sales_person_id as appointment_sales_person_id,
        a.sales_person_name as appointment_sales_person_name,
        dsp.sales_position as appointment_sales_person_position,
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
    left join {{ ref('dim_sales_persons') }} dsp
        on dsp.sales_person_id = a.sales_person_id
),

-- pre-aggregate every order down to 1 row per (lead, order_date) ONCE for the whole table,
-- instead of re-running this GROUP BY inside a correlated subquery for every appointment.
-- Orders in the same checkout group split across multiple order_number rows on the same
-- order_date are collapsed here.
-- order_sales_position is the order's own primary_sales_person_id resolved via dim_sales_persons
-- (not lo.sales_position, which is copied from the lead's assigned salesperson at lead-creation
-- time and is frequently blank) -- exposed as-is so BI can filter/group by online vs offline itself.
lead_order_dates as (
    select
        lo.lead_id_unified,
        lo.order_date,
        string_agg(distinct lo.lead_name_has_order_number, ', ') as order_number,
        string_agg(distinct fso.order_id, ', ') as order_id,
        string_agg(distinct dsp.sales_position, ', ') as order_sales_position,
        sum(lo.total_price_lead_name_has_order) as order_revenue
    from {{ ref('fct_sales_leads_orders') }} lo
    left join {{ ref('fct_sales_orders') }} fso
        on fso.order_number = lo.lead_name_has_order_number
    left join {{ ref('dim_sales_persons') }} dsp
        on dsp.sales_person_id = fso.primary_sales_person_id
    where lo.lead_name_has_order_group is not null
    group by lo.lead_id_unified, lo.order_date
),

-- every (appointment, candidate order on/after its scheduled_date) pair for the same lead,
-- ranked so the earliest order per appointment can be picked without a correlated lateral join
appointment_candidate_orders as (
    select
        ap.appointment_id,
        lod.order_date,
        lod.order_number,
        lod.order_id,
        lod.order_sales_position,
        lod.order_revenue,
        row_number() over (
            partition by ap.appointment_id
            order by lod.order_date asc
        ) as order_rank
    from appointments ap
    join lead_order_dates lod
        on lod.lead_id_unified = ap.resolved_lead_id
        and lod.order_date >= ap.scheduled_date
),

appointment_first_order as (
    select appointment_id, order_date, order_number, order_id, order_sales_position, order_revenue
    from appointment_candidate_orders
    where order_rank = 1
),

-- 2 appointments of the same lead in the same calendar month can both resolve to the same next
-- order (e.g. lead re-books before converting) -- only the appointment closest to the order date
-- keeps the revenue credit, so summing order_revenue across appointments doesn't double count
-- the order.
appointment_order_dedup as (
    select
        afo.appointment_id,
        afo.order_date,
        afo.order_number,
        afo.order_id,
        afo.order_sales_position,
        afo.order_revenue,
        row_number() over (
            partition by ap.resolved_lead_id, date_trunc('month', ap.scheduled_date), afo.order_date
            order by ap.scheduled_date desc
        ) as credit_rank
    from appointment_first_order afo
    join appointments ap on ap.appointment_id = afo.appointment_id
),

appointment_order as (
    select
        ap.*,
        aod.order_date as first_order_date,
        aod.order_number as first_order_number,
        aod.order_id as first_order_id,
        aod.order_sales_position as first_order_sales_position,
        case when aod.credit_rank = 1 then aod.order_revenue else 0 end as first_order_revenue
    from appointments ap
    left join appointment_order_dedup aod on aod.appointment_id = ap.appointment_id
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
    appointment_sales_person_id,
    appointment_sales_person_name,
    appointment_sales_person_position,
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
    first_order_sales_position as order_sales_position,
    coalesce(first_order_revenue, 0) as order_revenue
from appointment_order
