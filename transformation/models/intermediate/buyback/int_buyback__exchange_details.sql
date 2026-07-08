{{ config(
    materialized='view',
    schema='intermediate'
) }}

select
    be.name,
    be.instance_type,
    be.status,
    (be.submitted_date + INTERVAL '7 hours')::date AS submitted_date,
    be.customer_name,
    be.phone_number,
    be.national_id,
    be.order_code,
    be.new_order_code,
    be.refund_amount,
    be.reason,
    bei.product_name,
    bei.item_code,
    bei.prev_sales_order_item,
    bei.sale_price,
    bei.buyback_percentage,
    bei.calculated_buyback_price,
    bei.buyback_price,
    case
        when lower(item_code) like '%gia%' then 'Kim cương'
        else 'Vỏ trang sức'
    end as categories,
    CASE
        WHEN EXTRACT(HOUR FROM submitted_date + INTERVAL '7 hours') < 12 THEN 'Trước 12h'
        WHEN EXTRACT(HOUR FROM submitted_date + INTERVAL '7 hours') < 18 THEN 'Trước 18h'
        ELSE 'Sau 18h'
    END AS submitted_hour
from {{ ref('stg_erpnext__buyback_exchanges')}} as be left join
	 {{ ref('stg_erpnext__buyback_exchange_items')}} as bei ON be.name = bei.parent