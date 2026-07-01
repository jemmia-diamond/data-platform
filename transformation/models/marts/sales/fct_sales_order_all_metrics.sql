{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fso_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_fso_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_fso_sales_channel ON {{ this }} (sales_channel)",
      "CREATE INDEX IF NOT EXISTS idx_fso_date_customer ON {{ this }} (order_date, customer_id)",
    ]
) }}


with d_date as (
    select *
    from {{ ref('dim_sales_dates')}}
),
kpi as (
    select
        d.date_actual,
        kpi.sales_person_key,
        kpi.daily_target_amount,
        kpi.daily_target_leads
    from {{ ref('fct_sales_kpi_daily')}} kpi
    inner join d_date d on d.date_actual = kpi.date_actual
),
sales as (
	select
		o.order_date,
		o.order_id,
        o.order_number,
		o.split_order_group,
		o.customer_id,
		sa.sales_person_key,
		oi.product_key,
		oi.variant_id,
		o.sales_channel,
		o.sales_channel_raw,
		o.order_customer_type,
		o.location_name,
		o.assigned_location_name,
		o.total_price,
		case
		  	when total_price < 30*1000000 then '1. <30'
		  	when total_price >= 30*1000000 and total_price <= 50*1000000 then '2. 30-50'
		  	when total_price > 50*1000000 and total_price <= 80*1000000 then '3. 50-80'
		  	when total_price > 80*1000000 and total_price <= 120*1000000 then '4. 80-120'
		  	when total_price > 120*1000000 then '5. >120'
		end total_price_range,
		-- allocated total_price do 1 order có nhiều product và nhiều salesperson
		count(*) over (partition by o.order_id) as total_order_id_cnt,
		o.total_price / count(*) over (partition by o.order_id) as allocated_total_price_by_order_id,
		-- allocated amount này là hoa hồng
		sa.allocated_amount,
		-- chia allocated kpi như allocated total price vì bị dup như trên
		sa.allocated_amount / count(*) over (partition by o.order_id, sa.sales_person_key) as allocated_amount_by_order_id,
		-- chia product quantity và total price theo order_id và product_id
		oi.quantity as product_quantity,
		oi.quantity / count(*) over (partition by o.order_id, oi.product_key) as allocated_product_quantity_by_order_id,
		oi.line_gross_amount as product_total_price,
		oi.line_gross_amount/ count(*) over (partition by o.order_id, oi.product_key) as allocated_product_total_price_by_order_id,
		-- customer
		dc.age_group as customer_age_group,
		dc.gender as customer_gender,
		dc.default_province as customer_default_province,
		coalesce(dc.lead_source_name, 'Chưa xác định') as customer_lead_source,
        dc.lead_name,
		o.purchase_purposes,
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
        o.payment_status,
        o.closed_status,
        o.carrier_status
	from {{ ref('fct_sales_orders')}} o
	left join {{ ref('fct_sales_order_items')}} oi on o.order_id = oi.order_id
	left join {{ ref('fct_sales_attributions')}} sa on sa.order_id = o.order_id
	left join {{ ref('dim_sales_customers')}} dc on o.customer_id = dc.customer_id
	left join {{ ref('dim_sales_products')}} dp on dp.product_key = oi.product_key and dp.variant_id = oi.variant_id
),
sales_kpi as (
	select
		kpi.date_actual,
		kpi.sales_person_key as sales_person_key_kpi,
		kpi.daily_target_amount,
-- 		- do gom chung các bảng fact vào nên sẽ bị fan out (dup)
-- 		- daily target amount / count row (partition by date_actual, sales_person_key_kpi, split_order_group)
		count(*) over (partition by kpi.date_actual, kpi.sales_person_key) as total_order_id_kpi_cnt,
		kpi.daily_target_amount / count(*) over (partition by kpi.date_actual, kpi.sales_person_key) as allocated_daily_kpi_target_by_sales_person,
		s.*,
		-- salesperson
		ds.region_name as salesperson_region_name,
		ds.sales_position as salesperson_position,
		ds.sales_person_name as salesperson_name,
		ds.store_name as salesperson_store,
        ds.city_name as salesperson_city,
		ds.parent_sales_person as sales_person_parent
	from kpi kpi
	left join sales s on kpi.date_actual = s.order_date and kpi.sales_person_key = s.sales_person_key
	left join {{ ref('dim_sales_persons')}} ds on ds.sales_person_id = kpi.sales_person_key
)
select *
from sales_kpi