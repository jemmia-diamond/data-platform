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
	-- 	d.sales_person_key as sales_person_key_kpi,
	-- 	d.daily_target_amount,
		--- do gom chung các bảng fact vào nên sẽ bị fan out (dup)
		--- daily target amount / count row (partition by date_actual, sales_person_key_kpi, split_order_group)
	-- 	count(*) over (partition by d.date_actual, d.sales_person_key) as total_order_id_kpi_cnt,
	-- 	d.daily_target_amount / count(*) over (partition by d.date_actual, d.sales_person_key) as allocated_daily_kpi_target_by_sales_person,
		o.order_date,
		o.order_id,
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
		sa.allocated_amount / count(*) over (partition by o.order_id) as allocated_amount_by_order_id,
		-- chia product quantity và total price theo order_id và product_id
		oi.quantity as product_quantity,
		oi.quantity / count(*) over (partition by o.order_id, oi.product_key) as allocated_product_quantity_by_order_id,
		oi.line_gross_amount as product_total_price,
		oi.line_gross_amount/ count(*) over (partition by o.order_id, oi.product_key) as allocated_product_total_price_by_order_id,
		-- customer
		{{ filter_text('dc.age_group') }} as customer_age_group,
		{{ filter_text('dc.gender') }} as customer_gender,
		{{ filter_text('dc.default_province') }} as customer_default_province,
		{{ filter_text('dc.lead_source_name') }} as customer_lead_source,
        dc.lead_name,
		o.purchase_purposes,
		-- product
		{{ filter_text('dp.product_name') }} as product_name,
		{{ filter_text('dp.product_type') }} as product_type,
		{{ filter_text('dp.design_type') }} as design_type,
		{{ filter_text('dp.fineness') }} as fineness,
		{{ filter_text('dp.size_type') }} as size_type,
		{{ filter_text('dp.ring_size') }} as ring_size,
		{{ filter_text('dp.material_color') }} as material_color,
		dp.diamond_carat,
		{{ filter_text('dp.diamond_color', 'Không áp dụng') }} as diamond_color,
		{{ filter_text('dp.diamond_shape', 'Không áp dụng') }} as diamond_shape,
		{{ filter_text('dp.diamond_clarity', 'Không áp dụng') }} as diamond_clarity,
		{{ filter_text('dp.diamond_cut', 'Không áp dụng') }} as diamond_cut,
		{{ filter_text('dp.diamond_fluorescence', 'Không áp dụng') }} as diamond_fluorescence,
		dp.diamond_edge_size,
		{{ filter_text('dp.diamond_edge_size_display', 'Không áp dụng') }} as diamond_edge_size_display,
        {{ filter_text("left(diamond_edge_size_1::text, 3) || ' x ' || left(diamond_edge_size_2::text, 3)", 'Không áp dụng') }} as diamond_edge_size_transformed
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
		s.order_date,
		s.order_id,
		s.split_order_group,
		s.customer_id,
		COALESCE(s.sales_person_key, kpi.sales_person_key) as sales_person_key,
		s.product_key,
		s.variant_id,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.sales_channel') }} END as sales_channel,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.sales_channel_raw') }} END as sales_channel_raw,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.order_customer_type') }} END as order_customer_type,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.location_name') }} END as location_name,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.assigned_location_name') }} END as assigned_location_name,
		s.total_price,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.total_price_range') }} END as total_price_range,
		s.total_order_id_cnt,
		s.allocated_total_price_by_order_id,
		s.allocated_amount,
		s.allocated_amount_by_order_id,
		s.product_quantity,
		s.allocated_product_quantity_by_order_id,
		s.product_total_price,
		s.allocated_product_total_price_by_order_id,
		CASE WHEN s.order_id IS NULL THEN 'Không có khách hàng' ELSE {{ filter_text('s.customer_age_group') }} END as customer_age_group,
		CASE WHEN s.order_id IS NULL THEN 'Không có khách hàng' ELSE {{ filter_text('s.customer_gender') }} END as customer_gender,
		CASE WHEN s.order_id IS NULL THEN 'Không có khách hàng' ELSE {{ filter_text('s.customer_default_province') }} END as customer_default_province,
		CASE WHEN s.order_id IS NULL THEN 'Không có khách hàng' ELSE {{ filter_text('s.customer_lead_source') }} END as customer_lead_source,
        s.lead_name,
		CASE WHEN s.order_id IS NULL THEN 'Không có đơn hàng' ELSE {{ filter_text('s.purchase_purposes') }} END as purchase_purposes,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.product_name') }} END as product_name,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.product_type') }} END as product_type,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.design_type') }} END as design_type,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.fineness') }} END as fineness,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.size_type') }} END as size_type,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.ring_size') }} END as ring_size,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.material_color') }} END as material_color,
		s.diamond_carat,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_color', 'Không áp dụng') }} END as diamond_color,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_shape', 'Không áp dụng') }} END as diamond_shape,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_clarity', 'Không áp dụng') }} END as diamond_clarity,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_cut', 'Không áp dụng') }} END as diamond_cut,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_fluorescence', 'Không áp dụng') }} END as diamond_fluorescence,
		s.diamond_edge_size,
		CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_edge_size_display', 'Không áp dụng') }} END as diamond_edge_size_display,
        CASE WHEN s.order_id IS NULL THEN 'Không có sản phẩm' ELSE {{ filter_text('s.diamond_edge_size_transformed', 'Không áp dụng') }} END as diamond_edge_size_transformed,
		-- salesperson
		{{ filter_text('ds.region_name') }} as salesperson_region_name,
		{{ filter_text('ds.sales_position') }} as salesperson_position,
		{{ filter_text('ds.sales_person_name') }} as salesperson_name,
		{{ filter_text('ds.store_name') }} as salesperson_store,
        {{ filter_text('ds.city_name') }} as salesperson_city,
		{{ filter_text('ds.parent_sales_person') }} as sales_person_parent
	from kpi kpi
	left join sales s on kpi.date_actual = s.order_date and kpi.sales_person_key = s.sales_person_key
	left join {{ ref('dim_sales_persons')}} ds on ds.sales_person_id = kpi.sales_person_key
)
select *
from sales_kpi
