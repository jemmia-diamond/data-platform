{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_attributions_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_attributions_sales_person_key ON {{ this }} (sales_person_key)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_attributions_date ON {{ this }} USING brin (order_date)",
    ]
) }}

WITH attributions AS (
    SELECT * FROM {{ ref('fct_sales_attributions') }}
),

orders AS (
    SELECT * FROM {{ ref('rpt_sales__orders') }}
),

sales_persons AS (
    SELECT * FROM {{ ref('dim_sales_persons') }}
),

order_attributes AS (
    SELECT * FROM {{ ref('rpt_sales__order_attributes') }}
)

SELECT
    a.attribution_key,
    a.order_id,
    a.erp_order_id,
    a.order_number,
    a.order_sales_team_id,
    a.sales_person_key,
    sp.sales_person_name AS sales_person_name,
    sp.region_name AS sales_person_region_name,
    sp.city_name AS sales_person_city_name,
    sp.store_name AS sales_person_store_name,
    sp.sales_position AS sales_person_position,
    sp.parent_sales_person,
    a.customer_id,
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
    o.customer_lead_scope_status,
    o.customer_lead_name,
    o.customer_lead_source_name,
    o.customer_lead_source_platform,
    o.customer_pancake_platform,
    o.customer_pancake_page_name,
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
    a.business_date,
    a.business_date_vn,
    a.order_date,
    a.sales_channel,
    o.sales_channel_raw,
    o.price_range,
    o.order_customer_type,
    o.location_name,
    o.assigned_location_name,
    o.shipping_ward,
    o.shipping_district,
    o.shipping_province,
    o.shipping_country,
    a.allocated_percentage,
    a.total_order_allocated_percentage,
    a.is_order_allocation_percent_anomaly,
    a.allocated_amount,
    a.incentives_amount,
    a.allocated_gross_amount,
    a.allocated_net_amount,
    a.allocated_quantity,
    (o.total_price * COALESCE(a.allocated_percentage, 100) / 100) AS allocated_total_price,
    a.payment_status,
    a.fulfillment_status,
    a.processing_status,
    oa.product_category_count,
    oa.product_categories,
    oa.purchase_purpose_count,
    oa.purchase_purposes
FROM attributions a
LEFT JOIN orders o
    ON a.order_id = o.order_id
LEFT JOIN sales_persons sp
    ON a.sales_person_key = sp.sales_person_id
LEFT JOIN order_attributes oa
    ON a.order_id = oa.order_id
