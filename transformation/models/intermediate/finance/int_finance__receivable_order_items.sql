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
		-- customer (from int_crm__customers)
		CASE
			WHEN c.birth_date IS NULL THEN '8. Chưa xác định'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 20 THEN '1. <20'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 25 THEN '2. 21-25'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 30 THEN '3. 26-30'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 40 THEN '4. 31-40'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 50 THEN '5. 41-50'
			WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date))::int <= 60 THEN '6. 51-60'
			ELSE '7. 61+'
		END as customer_age_group,
		c.gender as customer_gender,
		c.default_province as customer_default_province,
		coalesce(c.lead_source_name, 'Chưa xác định') as customer_lead_source,
        c.lead_name,
		-- product (from int_catalog__variants)
		v.variant_title as product_name,
		v.product_type,
		v.design_type,
		v.fineness,
		v.size_type,
		v.ring_size,
		v.material_color,
		v.diamond_carat,
		v.diamond_color,
		v.diamond_shape,
		v.diamond_clarity,
		v.diamond_cut,
		v.diamond_fluorescence,
		v.diamond_edge_size,
		v.diamond_edge_size_display,
        left(v.diamond_edge_size_1::text, 3)
        || ' x ' ||
        left(v.diamond_edge_size_2::text, 3) as diamond_edge_size_transformed,
        o.consultation_date,
        o.order_promotion,
        oi.new_promotions as order_item_promotion,
        o.processing_status,
        o.cancelled_status,
        o.confirmed_status,
        o.fulfillment_status,
        oi.status_info,
        o.payment_status,
        o.closed_status,
        o.carrier_status
	from {{ ref('int_finance__receivable_order')}} o
	left join {{ ref('int_sales__order_items')}} oi on o.order_id = oi.unified_sales_order_id
	left join {{ ref('int_crm__customers')}} c on c.unified_customer_id = o.customer_id
	left join {{ ref('int_catalog__variants')}} v on v.variant_id = oi.variant_id
	where v.product_type != 'Quà Tặng' or v.product_type is null
)
select *
from get_all_item_finance_sales_order
