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
        a.erp_sales_order_id,
        a.appointment_with,
        a.appointment_reason,
        a.scheduled_date,
        a.scheduled_time,
        a.scheduled_time_vn,
        a.at_store,
        a.notes,
        a.order_status,
        a.budget,
        a.created_at_vn,
        a.updated_at,
        a.updated_at_vn,
        a.sales_person_id as appointment_sales_person_id,
        a.sales_person_name as appointment_sales_person_name,
        dsp.sales_position as appointment_sales_person_position,
        a.status,
        -- party_id can be a Lead (new lead booking) or a Customer (existing customer booking a
        -- repeat appointment) depending on appointment_with. Resolve the Customer case back to
        -- its originating lead so BI can join appointments to lead-level facts.
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

-- the order staff linked directly on the appointment in ERPNext (Appointment.sales_order).
-- No inference: an appointment without a linked order (or whose linked order is not a valid
-- order in fct_sales_orders) has no order.
linked_orders as (
    select
        ap.appointment_id,
        ap.scheduled_date,
        fso.order_id,
        fso.order_date,
        fso.split_order_group_name as order_group,
        coalesce(fso.split_order_group, fso.order_id) as split_key
    from appointments ap
    join {{ ref('fct_sales_orders') }} fso
        on fso.erp_order_id = ap.erp_sales_order_id
),

-- one checkout can be split into several orders (split_order_group); the appointment is
-- credited with the whole group: every order number in it and its total revenue
order_groups as (
    select
        coalesce(fso.split_order_group, fso.order_id) as split_key,
        string_agg(distinct fso.order_number, ', ') as order_number,
        string_agg(distinct dsp.sales_position, ', ') as order_sales_position,
        sum(fso.total_price) as order_revenue
    from {{ ref('fct_sales_orders') }} fso
    left join {{ ref('dim_sales_persons') }} dsp
        on dsp.sales_person_id = fso.primary_sales_person_id
    where coalesce(fso.split_order_group, fso.order_id) in (select split_key from linked_orders)
    group by coalesce(fso.split_order_group, fso.order_id)
),

-- several appointments can be linked to orders of the same group (e.g. the customer
-- re-books before buying) -- only the latest appointment keeps the revenue credit, so
-- summing order_revenue across appointments doesn't double count the group.
appointment_order as (
    select
        lo.appointment_id,
        lo.order_date,
        lo.order_id,
        lo.order_group,
        og.order_number,
        og.order_sales_position,
        case
            when row_number() over (
                partition by lo.split_key
                order by lo.scheduled_date desc, lo.appointment_id desc
            ) = 1 then og.order_revenue
            else 0
        end as order_revenue
    from linked_orders lo
    join order_groups og on og.split_key = lo.split_key
)

select
    ap.appointment_id,
    ap.lead_id,
    ap.party_id,
    ap.erp_sales_order_id,
    ap.appointment_with,
    case
        when ap.appointment_with = 'Customer' then 'Khách cũ'
        else 'Khách mới'
    end as appointment_with_display,
    ap.appointment_reason,
    ap.notes,
    ap.order_status,
    ap.budget,
    ap.created_at_vn,
    ap.updated_at,
    ap.updated_at_vn,
    ap.resolved_lead_id,
    ap.scheduled_date,
    ap.scheduled_time,
    ap.appointment_sales_person_id,
    ap.appointment_sales_person_name,
    ap.appointment_sales_person_position,
    ap.status,
    -- overdue takes priority over "due today": an Open appointment scheduled earlier today
    -- whose time has already passed is 'Quá hạn', not 'Cần follow'
    case
        when ap.status = 'Cancelled' then 'Hủy'
        when ap.status = 'Done' then 'Thành công'
        when ap.status = 'Open' and ap.scheduled_time_vn < (now() at time zone 'Asia/Ho_Chi_Minh') then 'Quá hạn'
        when ap.status = 'Open' and ap.scheduled_time_vn::date = (now() at time zone 'Asia/Ho_Chi_Minh')::date then 'Cần follow'
        when ap.status = 'Open' then 'Đang chờ'
    end as status_display,
    case
        when ap.at_store like '%Cần Thơ%' then 'Cần Thơ'
        when ap.at_store like '%Hà Nội%' then 'Hà Nội'
        when ap.at_store like '%Hồ Chí Minh%' then 'Hồ Chí Minh'
    end as at_store_transformed,
    (ao.order_id is not null) as has_order,
    ao.order_date,
    ao.order_number,
    ao.order_id,
    ao.order_sales_position,
    coalesce(ao.order_revenue, 0) as order_revenue,
    ao.order_group
from appointments ap
left join appointment_order ao on ao.appointment_id = ap.appointment_id
