{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_product_categories_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_product_categories_category_id ON {{ this }} (product_category_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_order_product_categories_order_date ON {{ this }} USING brin (order_date)",
    ]
) }}

WITH orders AS (
    SELECT * FROM {{ ref('rpt_sales_orders_dashboard') }}
),

order_attributes AS (
    SELECT * FROM {{ ref('rpt_sales_order_attributes_dashboard') }}
),

categories AS (
    SELECT
        op.order_id,
        op.product_category_id,
        op.category_name,
        COUNT(*) OVER (PARTITION BY op.order_id) AS product_category_count,
        ROW_NUMBER() OVER (
            PARTITION BY op.order_id
            ORDER BY op.category_name, op.product_category_id
        ) AS product_category_rank
    FROM {{ ref('fct_sales_order_product_categories') }} op
)

SELECT
    c.order_id || ':' || c.product_category_id AS order_product_category_key,
    o.order_id,
    o.order_number,
    o.real_created_at,
    o.real_created_at_vn,
    o.order_date,
    o.customer_id,
    o.customer_name,
    o.customer_email,
    o.customer_phone,
    o.customer_gender,
    o.customer_age,
    o.customer_age_group,
    o.customer_default_province,
    o.customer_default_district,
    o.customer_default_ward,
    o.customer_rank,
    o.customer_rank_raw,
    o.customer_journey,
    o.accepts_marketing,
    o.customer_total_orders,
    o.is_repeat_customer,
    o.customer_lead_id,
    o.customer_lead_name,
    o.customer_lead_source_name,
    o.customer_lead_source_platform,
    o.customer_pancake_platform,
    o.customer_lead_budget_label,
    o.customer_lead_demand_label,
    o.customer_lead_status,
    o.customer_lead_qualification_status,
    o.customer_lead_is_converted,
    o.customer_lead_order_group_key,
    o.customer_lead_order_group_rank,
    o.customer_lead_order_group_at,
    o.customer_lead_order_group_date,
    o.is_customer_lead_first_order_group,
    o.primary_sales_person_id,
    o.primary_sales_person_name,
    o.sales_region_name,
    o.sales_city_name,
    o.sales_store_name,
    o.sales_position,
    o.sales_channel,
    o.sales_channel_raw,
    o.payment_status,
    o.fulfillment_status,
    o.processing_status,
    o.order_customer_type,
    o.location_name,
    o.assigned_location_name,
    o.shipping_province,
    o.shipping_district,
    o.price_range,
    oa.product_categories,
    oa.purchase_purposes,
    c.product_category_id,
    c.category_name,
    c.product_category_count,
    c.product_category_rank,
    o.total_price,
    o.grand_total,
    o.net_amount,
    o.gross_amount,
    o.discount_amount,
    o.paid_amount,
    o.total_qty,
    o.total_price / NULLIF(c.product_category_count, 0) AS allocated_total_price,
    o.grand_total / NULLIF(c.product_category_count, 0) AS allocated_grand_total,
    o.net_amount / NULLIF(c.product_category_count, 0) AS allocated_net_amount,
    o.gross_amount / NULLIF(c.product_category_count, 0) AS allocated_gross_amount,
    o.total_qty / NULLIF(c.product_category_count, 0) AS allocated_quantity
FROM categories c
INNER JOIN orders o
    ON c.order_id = o.order_id
LEFT JOIN order_attributes oa
    ON o.order_id = oa.order_id
