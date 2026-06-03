{{ config(
    materialized='table',
    schema='marts_sales'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('int_sales__orders') }}
)

SELECT
    -- === IDENTIFIERS ===
    unified_sales_order_id AS order_id,
    order_number,
    first_order_at AS real_created_at,
    first_order_at::date AS order_date,
    erp_sales_order_id AS erp_order_id,
    haravan_order_id AS hrv_order_id,
    split_order_group_name,
    split_order_group,

    -- === CUSTOMER ===
    unified_customer_id as customer_id,
    customer_name,
    customer_email,
    customer_phone,
    haravan_staff_user_id AS staff_id,

    -- === SALES CHANNEL ===
    CASE sales_channel
        WHEN 'pos-cua-hang-hn' THEN 'POS - Hà Nội'
        WHEN 'pos-cua-hang-hcm' THEN 'POS - Hồ Chí Minh'
        WHEN 'pos cua hang can tho' THEN 'POS - Cần Thơ'
        WHEN 'pos' THEN 'POS - Chưa xác định'
        WHEN 'staff' THEN 'Nhân viên'
        ELSE 'Kênh online'
    END AS sales_channel,
    sales_channel AS sales_channel_raw,

    -- === DATES ===
    expected_delivery_date,
    expected_payment_date,
    consultation_date,
    fulfillment_completion_date,

    -- === REVENUE ===
    gross_amount,
    net_amount,
    haravan_discount_amount AS discount_amount,
    tax_amount,
    erp_grand_total AS grand_total,
    rounded_total,
    paid_amount,

    -- === REVENUE BREAKDOWN (Haravan) ===
    haravan_subtotal_price AS subtotal_amount,
    haravan_total_price AS total_price,
    haravan_total_tax AS total_tax,
    haravan_total_line_items_price AS line_items_total,

    -- === REVENUE BREAKDOWN (ERPNext) ===
    erp_total AS erp_total_amount,
    erp_net_total AS erp_net_amount,
    erp_total_amount AS erp_gross_amount,

    -- === REVENUE BREAKDOWN (ERPNext - base currency) ===
    base_total,
    base_net_total,
    base_grand_total,
    base_discount_amount,

    -- === QUANTITY & WEIGHT ===
    total_qty,
    total_net_weight,
    haravan_total_weight AS total_weight,

    -- === SHIPPING ===
    shipping_name,
    shipping_phone,
    shipping_address1,
    shipping_ward,
    shipping_district,
    shipping_province,
    shipping_country,
    haravan_location_name AS location_name,
    assigned_location_name,
    latest_transaction_kind,

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
    END AS closed_status,

    -- === CUSTOMER TYPE ===
    CASE
        WHEN order_customer_type IN ('New Customer', '') OR order_customer_type IS NULL THEN 'Khách mới'
        ELSE 'Khách cũ'
    END AS order_customer_type,

    -- === NOTES ===
    haravan_tags AS tags,
    haravan_note AS note,
    order_policies

FROM orders
WHERE order_number LIKE 'ORDER%'
  AND sales_channel NOT IN ('sendo', 'harafunnel')
  AND sales_channel NOT LIKE '%bhsc%'
  AND haravan_cancelled_status = 'uncancelled'
  AND haravan_confirmed_status = 'confirmed'
  AND (haravan_tags IS NULL OR haravan_tags NOT LIKE '%Lên bù cho đơn SO%')
  AND haravan_total_price > '120000'
