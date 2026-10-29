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
        a.erp_order_number,
        a.erp_order_group_names,
        a.erp_group_order_grand_total,
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

-- the order staff linked on the appointment in ERPNext. ERPNext resolves the order number,
-- the split order group and the group grand total itself (e_order, sales_order_group_names,
-- group_order_grand_total) -- they are taken as-is, no recomputation here.
-- fct_sales_orders is only looked up for order_date / order_sales_position.
-- several appointments can be linked to the same order group (e.g. the customer re-books
-- before buying) -- only the latest appointment keeps the revenue credit, so summing
-- order_revenue across appointments doesn't double count the group.
appointment_order as (
    select
        ap.appointment_id,
        fso.order_date,
        ap.erp_sales_order_id as order_id,
        ap.erp_order_group_names as order_group,
        ap.erp_order_number as order_number,
        dsp.sales_position as order_sales_position,
        case
            when row_number() over (
                partition by coalesce(ap.erp_order_group_names, ap.erp_order_number)
                order by ap.scheduled_date desc, ap.appointment_id desc
            ) = 1 then ap.erp_group_order_grand_total
            else 0
        end as order_revenue
    from appointments ap
    left join {{ ref('fct_sales_orders') }} fso
        on fso.erp_order_id = ap.erp_sales_order_id
    left join {{ ref('dim_sales_persons') }} dsp
        on dsp.sales_person_id = fso.primary_sales_person_id
    where ap.erp_order_number is not null
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
    (ao.order_number is not null) as has_order,
    ao.order_date,
    ao.order_number,
    ao.order_id,
    ao.order_sales_position,
    coalesce(ao.order_revenue, 0) as order_revenue,
    ao.order_group
from appointments ap
left join appointment_order ao on ao.appointment_id = ap.appointment_id
