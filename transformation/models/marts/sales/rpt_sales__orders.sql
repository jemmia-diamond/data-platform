{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_orders_order_date ON {{ this }} USING brin (order_date)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_orders_customer_id ON {{ this }} (customer_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_orders_sales_channel ON {{ this }} (sales_channel)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_orders_region ON {{ this }} (sales_region_name)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_orders_customer_lead_id ON {{ this }} (customer_lead_id)",
    ]
) }}

WITH orders AS (
    SELECT * FROM {{ ref('fct_sales_orders') }}
),

customers AS (
    SELECT * FROM {{ ref('dim_sales_customers') }}
),

sales_persons AS (
    SELECT * FROM {{ ref('dim_sales_persons') }}
),

leads AS (
    SELECT * FROM {{ ref('rpt_sales__leads') }}
),

order_attributes AS (
    SELECT * FROM {{ ref('rpt_sales__order_attributes') }}
),

enriched_orders AS (
SELECT
    -- === ORDER GRAIN ===
    o.order_id,
    o.order_number,
    o.real_created_at,
    o.real_created_at_vn,
    o.order_date,
    o.erp_order_id,
    o.hrv_order_id,
    o.split_order_group_name,
    o.split_order_group,
    CASE
        WHEN NULLIF(c.lead_name, '') IS NOT NULL THEN COALESCE(o.split_order_group::text, o.order_id::text)
    END AS customer_lead_order_group_key,

    -- === CUSTOMER ===
    o.customer_id,
    o.customer_name,
    o.customer_email,
    o.customer_phone,
    {{ filter_text('c.gender') }} AS customer_gender,
    c.customer_age,
    {{ filter_text('c.age_group') }} AS customer_age_group,
    {{ filter_text('c.default_province') }} AS customer_default_province,
    {{ filter_text('c.default_district') }} AS customer_default_district,
    {{ filter_text('c.default_ward') }} AS customer_default_ward,
    {{ filter_text('c.customer_rank') }} AS customer_rank,
    {{ filter_text('c.rank') }} AS customer_rank_raw,
    {{ filter_text('c.customer_journey') }} AS customer_journey,
    NULLIF(c.lead_name, '') AS customer_lead_id,
    {{ filter_text('l.lead_name', 'Không có lead') }} AS customer_lead_name,
    COALESCE(
        NULLIF(NULLIF(TRIM(l.lead_source_name), ''), 'Chưa xác định'),
        NULLIF(NULLIF(TRIM(c.lead_source_name), ''), 'Chưa xác định'),
        'Chưa xác định'
    ) AS customer_lead_source_name,
    {{ filter_text('l.lead_source_platform') }} AS customer_lead_source_platform,
    COALESCE(
        NULLIF(NULLIF(TRIM(l.pancake_platform), ''), 'Chưa xác định'),
        NULLIF(NULLIF(TRIM(c.pancake_platform), ''), 'Chưa xác định'),
        'Chưa xác định'
    ) AS customer_pancake_platform,
    {{ filter_text('l.pancake_page_name', 'Không có lead') }} AS customer_pancake_page_name,
    {{ filter_text('l.budget_label', 'Chưa khai báo') }} AS customer_lead_budget_label,
    {{ filter_text('l.demand_label', 'Chưa khai báo') }} AS customer_lead_demand_label,
    {{ filter_text('l.lead_status', 'Không có lead') }} AS customer_lead_status,
    {{ filter_text('l.qualification_status', 'Không có lead') }} AS customer_lead_qualification_status,
    l.is_converted AS customer_lead_is_converted,
    l.lead_entry_date AS customer_lead_entry_date,
    l.converted_date AS customer_lead_converted_date,
    c.accepts_marketing,
    c.total_orders AS customer_total_orders,
    c.is_repeat_customer,

    -- === SALES PERSON ===
    o.primary_sales_person_id,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.sales_person_name', 'Chưa gán sales') }}
    END AS primary_sales_person_name,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.region_name', 'Chưa gán vùng') }}
    END AS sales_region_name,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.city_name', 'Chưa gán thành phố') }}
    END AS sales_city_name,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.store_name', 'Chưa gán cửa hàng') }}
    END AS sales_store_name,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.sales_position') }}
    END AS sales_position,
    CASE
        WHEN o.primary_sales_person_id IS NULL THEN 'Chưa gán sales'
        ELSE {{ filter_text('sp.parent_sales_person', 'Không có cấp trên') }}
    END AS parent_sales_person,

    -- === ORDER FILTERS ===
    o.sales_channel,
    o.sales_channel_raw,
    o.price_range,
    o.order_customer_type,
    o.payment_status,
    o.fulfillment_status,
    o.hrv_fulfillment_status,
    o.carrier_status,
    o.processing_status,
    o.confirmed_status,
    o.cancelled_status,
    o.closed_status,
    o.location_name,
    o.assigned_location_name,
    o.shipping_ward,
    o.shipping_district,
    o.shipping_province,
    o.shipping_country,

    -- === REVENUE ===
    o.gross_amount,
    o.net_amount,
    o.discount_amount,
    o.tax_amount,
    o.grand_total,
    o.rounded_total,
    o.paid_amount,
    o.subtotal_amount,
    o.total_price,
    o.total_tax,
    o.line_items_total,
    o.erp_total_amount,
    o.erp_net_amount,
    o.erp_gross_amount,
    o.base_total,
    o.base_net_total,
    o.base_grand_total,
    o.base_discount_amount,
    o.total_qty,
    o.total_net_weight,
    o.total_weight,

    -- === ERP CLASSIFICATIONS, 1 ROW PER ORDER ===
    oa.product_category_count,
    oa.product_categories,
    oa.purchase_purpose_count,
    oa.purchase_purposes,

    -- === NOTES ===
    o.tags,
    o.note,
    o.order_policies

FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN leads l
    ON NULLIF(c.lead_name, '') = l.lead_id
LEFT JOIN sales_persons sp
    ON o.primary_sales_person_id = sp.sales_person_id
LEFT JOIN order_attributes oa
    ON o.order_id = oa.order_id
),

lead_order_groups AS (
    SELECT
        customer_lead_id,
        customer_lead_order_group_key,
        MIN(real_created_at) AS lead_order_group_at,
        MIN(order_date) AS lead_order_group_date
    FROM enriched_orders
    WHERE customer_lead_id IS NOT NULL
    GROUP BY 1, 2
),

ranked_lead_order_groups AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_lead_id
            ORDER BY lead_order_group_at NULLS LAST, lead_order_group_date NULLS LAST, customer_lead_order_group_key
        ) AS customer_lead_order_group_rank
    FROM lead_order_groups
)

SELECT
    eo.*,
    rlog.customer_lead_order_group_rank,
    rlog.lead_order_group_at AS customer_lead_order_group_at,
    rlog.lead_order_group_date AS customer_lead_order_group_date,
    COALESCE(rlog.customer_lead_order_group_rank = 1, FALSE) AS is_customer_lead_first_order_group
FROM enriched_orders eo
LEFT JOIN ranked_lead_order_groups rlog
    ON eo.customer_lead_id = rlog.customer_lead_id
    AND eo.customer_lead_order_group_key = rlog.customer_lead_order_group_key
