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
		o.primary_sales_person_id,
		sa.sales_person_key as sales_person_key_kpi,
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
		-- Allocate total_price because one order can have multiple products and multiple salespersons
		count(*) over (partition by o.order_id) as total_order_id_cnt,
		o.total_price / count(*) over (partition by o.order_id) as allocated_total_price_by_order_id,
		-- allocated amount is commission
		sa.allocated_amount,
		-- Allocate the KPI amount similarly to total_price due to the duplication mentioned above
		sa.allocated_amount / count(*) over (partition by o.order_id, sa.sales_person_key) as allocated_amount_by_order_id,
		-- Allocate product quantity and total price by order_id and product_id
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
		kpi.daily_target_amount,
        -- Duplication (fan-out effect) occurs due to combining multiple fact tables
		-- Formula: daily_target_amount / row_count (partitioned by date_actual and sales_person_key)
		count(*) over (partition by kpi.date_actual, kpi.sales_person_key) as total_order_id_kpi_cnt,
		kpi.daily_target_amount / count(*) over (partition by kpi.date_actual, kpi.sales_person_key) as allocated_daily_kpi_target_by_sales_person,
		s.*,
		-- primary salesperson
		primary_ds.region_name as primary_salesperson_region_name,
		primary_ds.sales_position as primary_salesperson_position,
		primary_ds.sales_person_name as primary_salesperson_name,
		primary_ds.store_name as primary_salesperson_store,
        trim(primary_ds.city_name) as primary_salesperson_city,
		primary_ds.parent_sales_person as primary_sales_person_parent,
		-- salesperson kpi
		ds.region_name as salesperson_region_name,
		ds.sales_position as salesperson_position,
		ds.sales_person_name as salesperson_name,
		ds.store_name as salesperson_store,
        trim(ds.city_name) as salesperson_city,
		ds.parent_sales_person as sales_person_parent
	from kpi kpi
	left join sales s on kpi.date_actual = s.order_date and kpi.sales_person_key = s.sales_person_key_kpi
	left join {{ ref('dim_sales_persons')}} ds on ds.sales_person_id = kpi.sales_person_key
	left join {{ ref('dim_sales_persons')}} primary_ds on primary_ds.sales_person_id = s.primary_sales_person_id
)
select *
from sales_kpi