{{ config(
    materialized='view',
    schema='intermediate'
) }}

select
    be.name,
    be.instance_type,
    be.status,
    be.submitted_date + INTERVAL '7 hours' AS submitted_date,
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
        when REGEXP_CONTAINS(item_code, 'gia') then 'Kim cương'
        when REGEXP_CONTAINS(item_code, 'GIA') then 'Kim cương'
        else 'Vỏ trang sức'
    end as categories,
    CASE
      WHEN HOUR(submitted_date) < 12 THEN "Trước 12h"
      WHEN HOUR(submitted_date) < 18 THEN "Trước 18h"
      ELSE "Sau 18h"
    END submitted_hour
from {{ ref('stg_erpnext__buyback_exchanges')}} as be left join
	 {{ ref('stg_erpnext__buyback_exchange_items')}} as bei ON be.name = bei.parent