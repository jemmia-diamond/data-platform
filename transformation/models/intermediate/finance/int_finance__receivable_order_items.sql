{{ config(
    materialized='view',
    schema='intermediate'
) }}

with get_all_item_finance_sales_order as (
	select
		o.order_date,
		o.order_id,
        o.order_number,
		o.split_order_group,
		o.customer_id,
		o.primary_sales_person_id,
		oi.variant_id as product_key,
		oi.variant_id,
		o.sales_channel,
		o.sales_channel_raw,
		o.order_customer_type,
		o.location_name,
		o.assigned_location_name,
		o.total_price,
		o.paid_amount,
		case
		  	when total_price < 30*1000000 then '1. <30'
		  	when total_price >= 30*1000000 and total_price <= 50*1000000 then '2. 30-50'
		  	when total_price > 50*1000000 and total_price <= 80*1000000 then '3. 50-80'
		  	when total_price > 80*1000000 and total_price <= 120*1000000 then '4. 80-120'
		  	when total_price > 120*1000000 then '5. >120'
		end total_price_range,
		o.expected_delivery_date,
        o.expected_payment_date,
		-- item_line
		oi.unified_sales_order_item_id as order_item_id,
		oi.haravan_line_item_id as haravan_line_item_id,
		oi.quantity as product_quantity,
		oi.line_gross_amount as product_total_price,
		oi.serial_numbers,
		oi.variant_title,
		-- customer
		dc.age_group as customer_age_group,
		dc.gender as customer_gender,
		dc.default_province as customer_default_province,
		coalesce(dc.lead_source_name, 'Chưa xác định') as customer_lead_source,
        dc.lead_name,
-- 		o.purchase_purposes,
		-- product
		dp.product_name,
		dp.product_type,
		dp.design_type,
		dp.fineness,
		dp.size_type,
		dp.ring_size,
		dp.material_color,
		dp.diamond_carat,
		dp.diamond_color,
		dp.diamond_shape,
		dp.diamond_clarity,
		dp.diamond_cut,
		dp.diamond_fluorescence,
		dp.diamond_edge_size,
		dp.diamond_edge_size_display,
        left(diamond_edge_size_1::text, 3)
        || ' x ' ||
        left(diamond_edge_size_2::text, 3) as diamond_edge_size_transformed,
        o.consultation_date,
        o.order_promotion,
        oi.new_promotions as order_item_promotion,
        o.processing_status,
        o.cancelled_status,
        o.confirmed_status,
        o.fulfillment_status,
        oi.status_info,
--         o.fina
        o.payment_status,
        o.closed_status,
        o.carrier_status
	from {{ ref('int_finance__receivable_order')}} o
	left join {{ ref('int_sales__order_items')}} oi on o.order_id = oi.unified_sales_order_id
	left join {{ ref('dim_sales_customers')}} dc on o.customer_id = dc.customer_id
	left join {{ ref('dim_sales_products')}} dp on dp.product_key = oi.variant_id and dp.variant_id = oi.variant_id
	where dp.product_type != 'Quà Tặng' or dp.product_type is null
)
select *
from get_all_item_finance_sales_order
