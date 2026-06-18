{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_orders_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_orders_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_orders_sales_person_id ON {{ this }} (primary_sales_person_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_orders_date_customer ON {{ this }} (order_date, customer_id)",
    ]
) }}

-- Metabot orders fact. Grain: 1 row = 1 order group.
-- Group key = COALESCE(split_order_group, unified_sales_order_id) — defensive against NULL split_order_group
--   (ERPNext only populates split_order_group for split orders; non-split ERP-only orders would be NULL and
--    collapse into a single mega-group without this COALESCE).
-- Dimensions use FIRST-NON-NULL by earliest physical order (COALESCE of haravan/erp/transaction/first_order timestamps).
-- Exceptions (additive, group-level STRING_AGG DISTINCT): product_categories, purchase_purposes.
-- Measures SUM across all orders in the group. Source: int_sales__orders (valid-order filter via macro).

WITH valid_orders AS (
    SELECT * FROM {{ ref('int_sales__orders') }}
    WHERE {{ metabot_valid_orders_filter() }}
),

group_cats AS (
    SELECT
        COALESCE(o.split_order_group, o.unified_sales_order_id) AS group_key,
        STRING_AGG(DISTINCT c.category_name, ' + ' ORDER BY c.category_name) AS product_categories
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_product_categories') }} c
        ON o.erp_sales_order_id = c.erp_sales_order_id
    WHERE c.category_name IS NOT NULL
    GROUP BY 1
),

group_purposes AS (
    SELECT
        COALESCE(o.split_order_group, o.unified_sales_order_id) AS group_key,
        STRING_AGG(DISTINCT p.purpose_name, ' + ' ORDER BY p.purpose_name) AS purchase_purposes
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_purchase_purposes') }} p
        ON o.erp_sales_order_id = p.erp_sales_order_id
    WHERE p.purpose_name IS NOT NULL
    GROUP BY 1
),

group_total AS (
    SELECT
        COALESCE(split_order_group, unified_sales_order_id) AS group_key,
        SUM(gross_amount) AS group_total_price
    FROM valid_orders
    GROUP BY 1
),

enriched AS (
    SELECT
        vo.unified_sales_order_id,
        COALESCE(vo.split_order_group, vo.unified_sales_order_id) AS group_key,
        vo.split_order_group_name,
        vo.haravan_created_at,
        vo.erp_created_at,
        vo.transaction_date,
        vo.first_order_at,
        vo.unified_customer_id AS customer_id,
        {{ mask_name('vo.customer_name') }} AS customer_name,
        vo.primary_sales_person AS primary_sales_person_id,
        CASE vo.sales_channel
            WHEN 'pos-cua-hang-hn' THEN 'POS - Hà Nội'
            WHEN 'pos-cua-hang-hcm' THEN 'POS - Hồ Chí Minh'
            WHEN 'pos cua hang can tho' THEN 'POS - Cần Thơ'
            WHEN 'pos' THEN 'POS - Chưa xác định'
            WHEN 'staff' THEN 'Nhân viên'
            ELSE 'Kênh online'
        END AS sales_channel,
        CASE vo.haravan_financial_status
            WHEN 'paid' THEN 'Đã thanh toán'
            WHEN 'pending' THEN 'Chờ thanh toán'
            WHEN 'partially_paid' THEN 'Thanh toán một phần'
            WHEN 'refunded' THEN 'Đã hoàn tiền'
            WHEN 'partially_refunded' THEN 'Hoàn tiền một phần'
            ELSE vo.haravan_financial_status
        END AS payment_status,
        CASE
            WHEN vo.fulfillment_status = 'success' THEN 'Đã giao hàng'
            WHEN vo.fulfillment_status = 'Fulfilled' THEN 'Đã giao hàng'
            WHEN vo.fulfillment_status = 'Not Fulfilled' THEN 'Chưa giao hàng'
            ELSE 'Chưa xác định'
        END AS fulfillment_status,
        CASE vo.haravan_processing_status
            WHEN 'complete' THEN 'Hoàn tất'
            WHEN 'cancel' THEN 'Đã hủy'
            WHEN 'self_delivery' THEN 'Tự giao hàng'
            WHEN 'confirmed' THEN 'Đã xác nhận'
            WHEN 'pending' THEN 'Chờ xử lý'
            ELSE 'Chưa xác định'
        END AS processing_status,
        CASE
            WHEN vo.order_customer_type IN ('New Customer', '') OR vo.order_customer_type IS NULL THEN 'Khách mới'
            ELSE 'Khách cũ'
        END AS order_customer_type,
        vo.gross_amount,
        vo.net_amount,
        COALESCE(vo.haravan_discount_amount, vo.erp_discount_amount) AS discount_amount,
        vo.tax_amount,
        vo.total_qty,
        COALESCE(vo.haravan_total_weight, vo.total_net_weight) AS total_weight,
        vo.haravan_location_name AS location_name,
        vo.shipping_province,
        vo.shipping_district
    FROM valid_orders vo
),

ranked AS (
    SELECT
        e.*,
        ROW_NUMBER() OVER (
            PARTITION BY e.group_key
            ORDER BY
                COALESCE(e.haravan_created_at, e.erp_created_at, e.transaction_date, e.first_order_at) NULLS LAST,
                e.unified_sales_order_id
        ) AS grp_rank
    FROM enriched e
),

group_agg AS (
    SELECT
        r.group_key,
        MAX(r.split_order_group_name) AS order_number,
        COUNT(*) AS order_count,
        MIN((r.first_order_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date) AS order_date,

        SUM(r.gross_amount) AS gross_amount_vnd,
        SUM(r.net_amount) AS net_amount_vnd,
        SUM(r.discount_amount) AS discount_amount_vnd,
        SUM(r.tax_amount) AS tax_amount_vnd,
        SUM(r.total_qty) AS total_qty,
        SUM(r.total_weight) AS total_weight,

        (ARRAY_AGG(r.customer_id ORDER BY r.grp_rank) FILTER (WHERE r.customer_id IS NOT NULL))[1] AS customer_id,
        (ARRAY_AGG(r.customer_name ORDER BY r.grp_rank) FILTER (WHERE r.customer_name IS NOT NULL))[1] AS customer_name,
        (ARRAY_AGG(r.primary_sales_person_id ORDER BY r.grp_rank) FILTER (WHERE r.primary_sales_person_id IS NOT NULL))[1] AS primary_sales_person_id,
        (ARRAY_AGG(r.sales_channel ORDER BY r.grp_rank) FILTER (WHERE r.sales_channel IS NOT NULL))[1] AS sales_channel,
        COALESCE((ARRAY_AGG(r.processing_status ORDER BY r.grp_rank) FILTER (WHERE r.processing_status IS NOT NULL))[1], 'Chưa xác định') AS processing_status,
        COALESCE((ARRAY_AGG(r.payment_status ORDER BY r.grp_rank) FILTER (WHERE r.payment_status IS NOT NULL))[1], 'Chưa xác định') AS payment_status,
        COALESCE((ARRAY_AGG(r.fulfillment_status ORDER BY r.grp_rank) FILTER (WHERE r.fulfillment_status IS NOT NULL))[1], 'Chưa xác định') AS fulfillment_status,
        COALESCE((ARRAY_AGG(r.order_customer_type ORDER BY r.grp_rank) FILTER (WHERE r.order_customer_type IS NOT NULL))[1], 'Chưa xác định') AS order_customer_type,
        (ARRAY_AGG(r.location_name ORDER BY r.grp_rank) FILTER (WHERE r.location_name IS NOT NULL))[1] AS store_name,
        (ARRAY_AGG(r.shipping_province ORDER BY r.grp_rank) FILTER (WHERE r.shipping_province IS NOT NULL))[1] AS shipping_province,
        (ARRAY_AGG(r.shipping_district ORDER BY r.grp_rank) FILTER (WHERE r.shipping_district IS NOT NULL))[1] AS shipping_district
    FROM ranked r
    GROUP BY r.group_key
)

SELECT
    ga.group_key AS order_id,
    ga.order_number,
    ga.order_count,
    ga.order_date,
    ga.customer_id,
    ga.customer_name,
    ga.primary_sales_person_id,
    ga.sales_channel,
    ga.processing_status,
    ga.payment_status,
    ga.fulfillment_status,
    ga.order_customer_type,
    ga.gross_amount_vnd,
    ga.net_amount_vnd,
    ga.discount_amount_vnd,
    ga.tax_amount_vnd,
    ga.total_qty,
    ga.total_weight,
    gc.product_categories,
    gp.purchase_purposes,
    ga.store_name,
    ga.shipping_province,
    ga.shipping_district,
    CASE
        WHEN gt.group_total_price < 30000000 THEN '1. <30'
        WHEN gt.group_total_price < 50000000 THEN '2. 30-50'
        WHEN gt.group_total_price < 80000000 THEN '3. 50-80'
        WHEN gt.group_total_price < 120000000 THEN '4. 80-120'
        WHEN gt.group_total_price < 200000000 THEN '5. 120-200'
        WHEN gt.group_total_price < 300000000 THEN '6. 200-300'
        WHEN gt.group_total_price < 500000000 THEN '7. 300-500'
        WHEN gt.group_total_price < 800000000 THEN '8. 500-800'
        WHEN gt.group_total_price < 1000000000 THEN '9. 800-1000'
        ELSE '10. >1000'
    END AS price_range
FROM group_agg ga
LEFT JOIN group_cats gc ON ga.group_key = gc.group_key
LEFT JOIN group_purposes gp ON ga.group_key = gp.group_key
LEFT JOIN group_total gt ON ga.group_key = gt.group_key
