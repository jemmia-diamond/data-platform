{{ config(
    materialized='view',
    schema='intermediate'
) }}

with
get_all_item_finance_sales_order as (
    select *
    from {{ ref('int_finance__receivable_order_items')}}
),

warehouses as (
    select
		variant_id,
		string_agg((location_name || ' : '::text) || qty_onhand, chr(10)) AS stock_info
	from {{ ref('int_inventory__stock_by_location')}}
	WHERE (qty_onhand <> 0 OR qty_available <> 0)
	AND location_id <> 1599762
	AND (
			variant_id IN (
			SELECT variant_id
			FROM get_all_item_finance_sales_order)
		)
	GROUP BY variant_id
),

processed_serials AS (
	SELECT
		sub.split_order_group,
	    sub.haravan_line_item_id,
	    string_agg((sub.sn_trimmed || ' : '::text) || COALESCE(to_char(vs.last_rfid_scan_time + '07:00:00'::interval, 'DD/MM/YYYY HH24:MI'::text), 'Chưa scan'::text), chr(10)) AS serial_scan_details
	FROM (
		SELECT
			split_order_group AS split_order_group,
			haravan_line_item_id as haravan_line_item_id,
			regexp_split_to_table(serial_numbers, '\n'::text) AS sn_trimmed
		FROM get_all_item_finance_sales_order
		WHERE serial_numbers IS NOT NULL AND serial_numbers <> ''::text
		) sub
	LEFT JOIN {{ ref('int_inventory__serials')}} vs ON sub.sn_trimmed = vs.serial_number
	GROUP BY 1,2
),
get_item_ready as (
	select
	    item.*,
	    ps.serial_scan_details,
		COALESCE(ps.serial_scan_details, 'Trống hoặc chưa có serial'::text) AS serial_with_time,
		COALESCE(stock.stock_info, 'Không có khả dụng hiện tại'::text) AS stock_summary,
		CASE
		    WHEN item.variant_title::text ~~ '%GIA%'::text THEN
		    CASE
		        WHEN stock.stock_info IS NOT NULL THEN 1
		        ELSE 0
		    END
		    WHEN ps.serial_scan_details IS NOT NULL AND stock.stock_info IS NOT NULL THEN 1
		    ELSE 0
		END AS is_item_ready
	FROM get_all_item_finance_sales_order item
	LEFT JOIN warehouses stock ON item.variant_id = stock.variant_id
	LEFT JOIN processed_serials ps ON item.split_order_group = ps.split_order_group AND item.haravan_line_item_id = ps.haravan_line_item_id
)
select *,
    CASE
		WHEN fulfillment_status::text = 'Đã giao hàng'::text THEN 'Đã giao hàng'::text
		WHEN min(is_item_ready) OVER (PARTITION BY order_number) = 1 THEN 'Đơn hàng đã về đủ'::text
		ELSE 'Đơn hàng chờ hàng/Serial'::text
	END AS order_fulfillment_status,
	total_price - paid_amount as congno
from get_item_ready

