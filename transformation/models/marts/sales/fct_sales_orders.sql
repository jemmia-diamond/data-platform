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

WITH orders AS (
    SELECT * FROM {{ ref('int_sales__orders') }}
    WHERE order_number LIKE 'ORDER%'
      AND sales_channel NOT IN ('sendo', 'harafunnel')
      AND sales_channel NOT LIKE '%bhsc%'
      AND haravan_cancelled_status = 'uncancelled'
      AND haravan_confirmed_status = 'confirmed'
      AND (haravan_tags IS NULL OR haravan_tags NOT LIKE '%Lên bù cho đơn SO%')
      AND haravan_total_price > '120000'
),

cat_agg AS (
    SELECT
        o.unified_sales_order_id AS order_id,
        STRING_AGG(opc.category_name, ' + ' ORDER BY opc.category_name) AS product_categories
    FROM orders o
    LEFT JOIN {{ ref('int_sales__order_product_categories') }} opc
        ON o.erp_sales_order_id = opc.erp_sales_order_id
    WHERE opc.category_name IS NOT NULL
    GROUP BY o.unified_sales_order_id
),

purpose_agg AS (
    SELECT
        o.unified_sales_order_id AS order_id,
        STRING_AGG(opp.purpose_name, ' + ' ORDER BY opp.purpose_name) AS purchase_purposes
    FROM orders o
    LEFT JOIN {{ ref('int_sales__order_purchase_purposes') }} opp
        ON o.erp_sales_order_id = opp.erp_sales_order_id
    WHERE opp.purpose_name IS NOT NULL
    GROUP BY o.unified_sales_order_id
),

group_total AS (
    SELECT
        COALESCE(split_order_group, unified_sales_order_id) AS split_key,
        SUM(haravan_total_price::numeric) AS group_total_price
    FROM orders
    GROUP BY COALESCE(split_order_group, unified_sales_order_id)
)

SELECT
    -- === IDENTIFIERS ===
    unified_sales_order_id AS order_id,
    order_number,
    first_order_at AS real_created_at,
    first_order_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS real_created_at_vn,
    (first_order_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS order_date,
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
    primary_sales_person AS primary_sales_person_id,

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
    order_policies,

    -- === PRICE RANGE (by split_order_group) ===
    CASE
        WHEN gt.group_total_price < 30000000 THEN '1. <30'
        WHEN gt.group_total_price >= 30000000 AND gt.group_total_price < 50000000 THEN '2. 30-50'
        WHEN gt.group_total_price >= 50000000 AND gt.group_total_price < 80000000 THEN '3. 50-80'
        WHEN gt.group_total_price >= 80000000 AND gt.group_total_price < 120000000 THEN '4. 80-120'
        WHEN gt.group_total_price >= 120000000 AND gt.group_total_price < 200000000 THEN '5. 120-200'
        WHEN gt.group_total_price >= 200000000 AND gt.group_total_price < 300000000 THEN '6. 200-300'
        WHEN gt.group_total_price >= 300000000 AND gt.group_total_price < 500000000 THEN '7. 300-500'
        WHEN gt.group_total_price >= 500000000 AND gt.group_total_price < 800000000 THEN '8. 500-800'
        WHEN gt.group_total_price >= 800000000 AND gt.group_total_price < 1000000000 THEN '9. 800-1000'
        ELSE '10. >1000'
    END AS price_range,

    -- === CLASSIFICATION (ERPNext) ===
    ca.product_categories,
    pa.purchase_purposes

FROM orders
LEFT JOIN cat_agg ca ON orders.unified_sales_order_id = ca.order_id
LEFT JOIN purpose_agg pa ON orders.unified_sales_order_id = pa.order_id
LEFT JOIN group_total gt ON COALESCE(orders.split_order_group, orders.unified_sales_order_id) = gt.split_key
