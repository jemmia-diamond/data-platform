{{ config(
    materialized='view',
    schema='intermediate'
) }}


with int_finance_sales_order as (
	select
		o.real_order_date as order_date,
		unified_sales_order_id as order_id,
		o.order_number,
		o.split_order_group,
		o.unified_customer_id as customer_id,
		o.primary_sales_person as primary_sales_person_id,
	-- 	oi.product_key,
	-- 	oi.variant_id,
		CASE sales_channel
	        WHEN 'pos-cua-hang-hn' THEN 'POS - Hà Nội'
	        WHEN 'pos-cua-hang-hcm' THEN 'POS - Hồ Chí Minh'
	        WHEN 'pos cua hang can tho' THEN 'POS - Cần Thơ'
	        WHEN 'pos' THEN 'POS - Chưa xác định'
	        WHEN 'staff' THEN 'Nhân viên'
	        ELSE 'Kênh online'
	    END AS sales_channel,
	    sales_channel AS sales_channel_raw,
		o.order_customer_type,
		o.haravan_location_name as location_name,
		o.assigned_location_name,
		haravan_total_price AS total_price,
		o.paid_amount,
		o.expected_delivery_date,
	    o.expected_payment_date,

	    o.consultation_date,
		o.order_promotion,
	-- 	oi.new_promotions as order_item_promotion,
		-- === PAYMENT STATUS ===
	    CASE haravan_financial_status
	        WHEN 'paid' THEN 'Đã thanh toán'
	        WHEN 'pending' THEN 'Chờ thanh toán'
	        WHEN 'partially_paid' THEN 'Thanh toán một phần'
	        WHEN 'refunded' THEN 'Đã hoàn tiền'
	        WHEN 'partially_refunded' THEN 'Hoàn tiền một phần'
	        ELSE haravan_financial_status
	    END AS payment_status,

	    -- === FULFILLMENT STATUS ===
	    CASE
	        WHEN fulfillment_status = 'success' THEN 'Đã giao hàng'
	        WHEN fulfillment_status = 'Fulfilled' THEN 'Đã giao hàng'
	        WHEN fulfillment_status = 'Not Fulfilled' THEN 'Chưa giao hàng'
	        ELSE 'Chưa xác định'
	    END AS fulfillment_status,

	    CASE haravan_fulfillment_status
	        WHEN 'fulfilled' THEN 'Đã giao hàng'
	        WHEN 'notfulfilled' THEN 'Chưa giao hàng'
	        ELSE 'Chưa xác định'
	    END AS hrv_fulfillment_status,

	    haravan_carrier_status AS carrier_status,

	    -- === PROCESSING STATUS ===
	    CASE haravan_processing_status
	        WHEN 'complete' THEN 'Hoàn tất'
	        WHEN 'cancel' THEN 'Đã hủy'
	        WHEN 'self_delivery' THEN 'Tự giao hàng'
	        WHEN 'confirmed' THEN 'Đã xác nhận'
	        WHEN 'pending' THEN 'Chờ xử lý'
	        ELSE 'Chưa xác định'
	    END AS processing_status,

	    CASE haravan_confirmed_status
	        WHEN 'confirmed' THEN 'Đã xác nhận'
	        WHEN 'unconfirmed' THEN 'Chưa xác nhận'
	        ELSE 'Chưa xác định'
	    END AS confirmed_status,

	    CASE haravan_cancelled_status
	        WHEN 'cancelled' THEN 'Đã hủy'
	        WHEN 'uncancelled' THEN 'Chưa hủy'
	        ELSE 'Chưa xác định'
	    END AS cancelled_status,

	    CASE haravan_closed_status
	        WHEN 'closed' THEN 'Đã đóng'
	        WHEN 'unclosed' THEN 'Chưa đóng'
	        ELSE 'Chưa xác định'
	    END AS closed_status
	from {{ ref('int_sales__orders')}} o
	where
	1 = 1
	and haravan_cancelled_status = 'uncancelled'
	and erp_financial_status != 'Paid'
	and haravan_total_price >= 120000
	and sales_channel not in ('harafunnel', 'sendo', 'bhsc')
)
select *
from int_finance_sales_order
