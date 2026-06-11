{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_order_summary_lead_id ON {{ this }} (lead_id)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_order_summary_entry_date ON {{ this }} USING brin (lead_entry_date)",
      "CREATE INDEX IF NOT EXISTS idx_rpt_sales_leads_order_summary_first_group_date ON {{ this }} USING brin (first_order_group_date)",
    ]
) }}

WITH leads AS (
    SELECT * FROM {{ ref('rpt_sales__leads') }}
),

orders AS (
    SELECT * FROM {{ ref('rpt_sales__orders') }}
),

all_lead_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_lead_id
            ORDER BY real_created_at NULLS LAST, order_date NULLS LAST, order_id
        ) AS all_order_rank
    FROM orders
    WHERE customer_lead_id IS NOT NULL
),

all_order_summary AS (
    SELECT
        customer_lead_id AS lead_id,
        COUNT(*) AS all_order_count,
        STRING_AGG(order_number::text, ', ' ORDER BY all_order_rank) AS all_order_numbers,
        STRING_AGG(order_id::text, ', ' ORDER BY all_order_rank) AS all_order_ids,
        MIN(order_date) AS all_first_order_date,
        MAX(order_date) AS all_last_order_date,
        SUM(COALESCE(total_price, 0)) AS all_order_total_price,
        SUM(COALESCE(grand_total, 0)) AS all_order_grand_total,
        SUM(COALESCE(net_amount, 0)) AS all_order_net_amount,
        SUM(COALESCE(gross_amount, 0)) AS all_order_gross_amount,
        SUM(COALESCE(discount_amount, 0)) AS all_order_discount_amount,
        SUM(COALESCE(paid_amount, 0)) AS all_order_paid_amount,
        SUM(COALESCE(total_qty, 0)) AS all_order_total_qty,
        (ARRAY_AGG(order_id ORDER BY all_order_rank) FILTER (WHERE order_id IS NOT NULL))[1] AS all_first_order_id,
        (ARRAY_AGG(order_number ORDER BY all_order_rank) FILTER (WHERE order_number IS NOT NULL))[1] AS all_first_order_number,
        (ARRAY_AGG(real_created_at ORDER BY all_order_rank) FILTER (WHERE real_created_at IS NOT NULL))[1] AS all_first_order_at,
        (ARRAY_AGG(real_created_at_vn ORDER BY all_order_rank) FILTER (WHERE real_created_at_vn IS NOT NULL))[1] AS all_first_order_at_vn,
        (ARRAY_AGG(customer_id ORDER BY all_order_rank) FILTER (WHERE customer_id IS NOT NULL))[1] AS all_first_order_customer_id,
        (ARRAY_AGG(customer_name ORDER BY all_order_rank) FILTER (WHERE customer_name IS NOT NULL))[1] AS all_first_order_customer_name,
        (ARRAY_AGG(customer_email ORDER BY all_order_rank) FILTER (WHERE customer_email IS NOT NULL))[1] AS all_first_order_customer_email,
        (ARRAY_AGG(customer_phone ORDER BY all_order_rank) FILTER (WHERE customer_phone IS NOT NULL))[1] AS all_first_order_customer_phone,
        (ARRAY_AGG(customer_gender ORDER BY all_order_rank) FILTER (WHERE customer_gender IS NOT NULL))[1] AS all_first_order_customer_gender,
        (ARRAY_AGG(customer_age_group ORDER BY all_order_rank) FILTER (WHERE customer_age_group IS NOT NULL))[1] AS all_first_order_customer_age_group,
        (ARRAY_AGG(customer_default_province ORDER BY all_order_rank) FILTER (WHERE customer_default_province IS NOT NULL))[1] AS all_first_order_customer_default_province,
        (ARRAY_AGG(customer_default_district ORDER BY all_order_rank) FILTER (WHERE customer_default_district IS NOT NULL))[1] AS all_first_order_customer_default_district,
        (ARRAY_AGG(customer_rank ORDER BY all_order_rank) FILTER (WHERE customer_rank IS NOT NULL))[1] AS all_first_order_customer_rank,
        (ARRAY_AGG(customer_journey ORDER BY all_order_rank) FILTER (WHERE customer_journey IS NOT NULL))[1] AS all_first_order_customer_journey,
        (ARRAY_AGG(is_repeat_customer ORDER BY all_order_rank) FILTER (WHERE is_repeat_customer IS NOT NULL))[1] AS all_first_order_is_repeat_customer,
        (ARRAY_AGG(primary_sales_person_id ORDER BY all_order_rank) FILTER (WHERE primary_sales_person_id IS NOT NULL))[1] AS all_first_order_sales_person_id,
        (ARRAY_AGG(primary_sales_person_name ORDER BY all_order_rank) FILTER (WHERE primary_sales_person_name IS NOT NULL))[1] AS all_first_order_sales_person_name,
        (ARRAY_AGG(sales_region_name ORDER BY all_order_rank) FILTER (WHERE sales_region_name IS NOT NULL))[1] AS all_first_order_sales_region_name,
        (ARRAY_AGG(sales_city_name ORDER BY all_order_rank) FILTER (WHERE sales_city_name IS NOT NULL))[1] AS all_first_order_sales_city_name,
        (ARRAY_AGG(sales_store_name ORDER BY all_order_rank) FILTER (WHERE sales_store_name IS NOT NULL))[1] AS all_first_order_sales_store_name,
        (ARRAY_AGG(sales_position ORDER BY all_order_rank) FILTER (WHERE sales_position IS NOT NULL))[1] AS all_first_order_sales_position,
        (ARRAY_AGG(sales_channel ORDER BY all_order_rank) FILTER (WHERE sales_channel IS NOT NULL))[1] AS all_first_order_sales_channel,
        (ARRAY_AGG(sales_channel_raw ORDER BY all_order_rank) FILTER (WHERE sales_channel_raw IS NOT NULL))[1] AS all_first_order_sales_channel_raw,
        (ARRAY_AGG(price_range ORDER BY all_order_rank) FILTER (WHERE price_range IS NOT NULL))[1] AS all_first_order_price_range,
        (ARRAY_AGG(order_customer_type ORDER BY all_order_rank) FILTER (WHERE order_customer_type IS NOT NULL))[1] AS all_first_order_customer_type,
        (ARRAY_AGG(payment_status ORDER BY all_order_rank) FILTER (WHERE payment_status IS NOT NULL))[1] AS all_first_order_payment_status,
        (ARRAY_AGG(fulfillment_status ORDER BY all_order_rank) FILTER (WHERE fulfillment_status IS NOT NULL))[1] AS all_first_order_fulfillment_status,
        (ARRAY_AGG(processing_status ORDER BY all_order_rank) FILTER (WHERE processing_status IS NOT NULL))[1] AS all_first_order_processing_status,
        (ARRAY_AGG(location_name ORDER BY all_order_rank) FILTER (WHERE location_name IS NOT NULL))[1] AS all_first_order_location_name,
        (ARRAY_AGG(assigned_location_name ORDER BY all_order_rank) FILTER (WHERE assigned_location_name IS NOT NULL))[1] AS all_first_order_assigned_location_name,
        (ARRAY_AGG(shipping_province ORDER BY all_order_rank) FILTER (WHERE shipping_province IS NOT NULL))[1] AS all_first_order_shipping_province,
        (ARRAY_AGG(shipping_district ORDER BY all_order_rank) FILTER (WHERE shipping_district IS NOT NULL))[1] AS all_first_order_shipping_district,
        (ARRAY_AGG(product_categories ORDER BY all_order_rank) FILTER (WHERE product_categories IS NOT NULL))[1] AS all_first_order_product_categories,
        (ARRAY_AGG(purchase_purposes ORDER BY all_order_rank) FILTER (WHERE purchase_purposes IS NOT NULL))[1] AS all_first_order_purchase_purposes
    FROM all_lead_orders
    GROUP BY 1
),

first_group_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_lead_id
            ORDER BY real_created_at NULLS LAST, order_date NULLS LAST, order_id
        ) AS first_group_order_rank
    FROM orders
    WHERE customer_lead_id IS NOT NULL
      AND is_customer_lead_first_order_group
),

first_group_summary AS (
    SELECT
        customer_lead_id AS lead_id,
        MAX(customer_lead_order_group_key) AS first_order_group_key,
        MIN(customer_lead_order_group_at) AS first_order_group_at,
        MIN(customer_lead_order_group_date) AS first_order_group_date,
        COUNT(*) AS first_order_group_order_count,
        STRING_AGG(order_number::text, ', ' ORDER BY first_group_order_rank) AS first_order_group_order_numbers,
        STRING_AGG(order_id::text, ', ' ORDER BY first_group_order_rank) AS first_order_group_order_ids,
        SUM(COALESCE(total_price, 0)) AS first_order_group_total_price,
        SUM(COALESCE(grand_total, 0)) AS first_order_group_grand_total,
        SUM(COALESCE(net_amount, 0)) AS first_order_group_net_amount,
        SUM(COALESCE(gross_amount, 0)) AS first_order_group_gross_amount,
        SUM(COALESCE(discount_amount, 0)) AS first_order_group_discount_amount,
        SUM(COALESCE(paid_amount, 0)) AS first_order_group_paid_amount,
        SUM(COALESCE(total_qty, 0)) AS first_order_group_total_qty,
        (ARRAY_AGG(order_id ORDER BY first_group_order_rank) FILTER (WHERE order_id IS NOT NULL))[1] AS first_order_id,
        (ARRAY_AGG(order_number ORDER BY first_group_order_rank) FILTER (WHERE order_number IS NOT NULL))[1] AS first_order_number,
        (ARRAY_AGG(real_created_at ORDER BY first_group_order_rank) FILTER (WHERE real_created_at IS NOT NULL))[1] AS first_order_at,
        (ARRAY_AGG(real_created_at_vn ORDER BY first_group_order_rank) FILTER (WHERE real_created_at_vn IS NOT NULL))[1] AS first_order_at_vn,
        (ARRAY_AGG(order_date ORDER BY first_group_order_rank) FILTER (WHERE order_date IS NOT NULL))[1] AS first_order_date,
        (ARRAY_AGG(customer_id ORDER BY first_group_order_rank) FILTER (WHERE customer_id IS NOT NULL))[1] AS first_order_customer_id,
        (ARRAY_AGG(customer_name ORDER BY first_group_order_rank) FILTER (WHERE customer_name IS NOT NULL))[1] AS first_order_customer_name,
        (ARRAY_AGG(customer_email ORDER BY first_group_order_rank) FILTER (WHERE customer_email IS NOT NULL))[1] AS first_order_customer_email,
        (ARRAY_AGG(customer_phone ORDER BY first_group_order_rank) FILTER (WHERE customer_phone IS NOT NULL))[1] AS first_order_customer_phone,
        (ARRAY_AGG(customer_gender ORDER BY first_group_order_rank) FILTER (WHERE customer_gender IS NOT NULL))[1] AS first_order_customer_gender,
        (ARRAY_AGG(customer_age_group ORDER BY first_group_order_rank) FILTER (WHERE customer_age_group IS NOT NULL))[1] AS first_order_customer_age_group,
        (ARRAY_AGG(customer_default_province ORDER BY first_group_order_rank) FILTER (WHERE customer_default_province IS NOT NULL))[1] AS first_order_customer_default_province,
        (ARRAY_AGG(customer_default_district ORDER BY first_group_order_rank) FILTER (WHERE customer_default_district IS NOT NULL))[1] AS first_order_customer_default_district,
        (ARRAY_AGG(customer_rank ORDER BY first_group_order_rank) FILTER (WHERE customer_rank IS NOT NULL))[1] AS first_order_customer_rank,
        (ARRAY_AGG(customer_journey ORDER BY first_group_order_rank) FILTER (WHERE customer_journey IS NOT NULL))[1] AS first_order_customer_journey,
        (ARRAY_AGG(is_repeat_customer ORDER BY first_group_order_rank) FILTER (WHERE is_repeat_customer IS NOT NULL))[1] AS first_order_is_repeat_customer,
        (ARRAY_AGG(primary_sales_person_id ORDER BY first_group_order_rank) FILTER (WHERE primary_sales_person_id IS NOT NULL))[1] AS first_order_sales_person_id,
        (ARRAY_AGG(primary_sales_person_name ORDER BY first_group_order_rank) FILTER (WHERE primary_sales_person_name IS NOT NULL))[1] AS first_order_sales_person_name,
        (ARRAY_AGG(sales_region_name ORDER BY first_group_order_rank) FILTER (WHERE sales_region_name IS NOT NULL))[1] AS first_order_sales_region_name,
        (ARRAY_AGG(sales_city_name ORDER BY first_group_order_rank) FILTER (WHERE sales_city_name IS NOT NULL))[1] AS first_order_sales_city_name,
        (ARRAY_AGG(sales_store_name ORDER BY first_group_order_rank) FILTER (WHERE sales_store_name IS NOT NULL))[1] AS first_order_sales_store_name,
        (ARRAY_AGG(sales_position ORDER BY first_group_order_rank) FILTER (WHERE sales_position IS NOT NULL))[1] AS first_order_sales_position,
        (ARRAY_AGG(sales_channel ORDER BY first_group_order_rank) FILTER (WHERE sales_channel IS NOT NULL))[1] AS first_order_sales_channel,
        (ARRAY_AGG(sales_channel_raw ORDER BY first_group_order_rank) FILTER (WHERE sales_channel_raw IS NOT NULL))[1] AS first_order_sales_channel_raw,
        (ARRAY_AGG(price_range ORDER BY first_group_order_rank) FILTER (WHERE price_range IS NOT NULL))[1] AS first_order_price_range,
        (ARRAY_AGG(order_customer_type ORDER BY first_group_order_rank) FILTER (WHERE order_customer_type IS NOT NULL))[1] AS first_order_customer_type,
        (ARRAY_AGG(payment_status ORDER BY first_group_order_rank) FILTER (WHERE payment_status IS NOT NULL))[1] AS first_order_payment_status,
        (ARRAY_AGG(fulfillment_status ORDER BY first_group_order_rank) FILTER (WHERE fulfillment_status IS NOT NULL))[1] AS first_order_fulfillment_status,
        (ARRAY_AGG(processing_status ORDER BY first_group_order_rank) FILTER (WHERE processing_status IS NOT NULL))[1] AS first_order_processing_status,
        (ARRAY_AGG(location_name ORDER BY first_group_order_rank) FILTER (WHERE location_name IS NOT NULL))[1] AS first_order_location_name,
        (ARRAY_AGG(assigned_location_name ORDER BY first_group_order_rank) FILTER (WHERE assigned_location_name IS NOT NULL))[1] AS first_order_assigned_location_name,
        (ARRAY_AGG(shipping_province ORDER BY first_group_order_rank) FILTER (WHERE shipping_province IS NOT NULL))[1] AS first_order_shipping_province,
        (ARRAY_AGG(shipping_district ORDER BY first_group_order_rank) FILTER (WHERE shipping_district IS NOT NULL))[1] AS first_order_shipping_district,
        (ARRAY_AGG(product_categories ORDER BY first_group_order_rank) FILTER (WHERE product_categories IS NOT NULL))[1] AS first_order_product_categories,
        (ARRAY_AGG(purchase_purposes ORDER BY first_group_order_rank) FILTER (WHERE purchase_purposes IS NOT NULL))[1] AS first_order_purchase_purposes
    FROM first_group_orders
    GROUP BY 1
)

SELECT
    l.*,
    COALESCE(ao.all_order_count, 0) AS all_order_count,
    ao.all_order_numbers,
    ao.all_order_ids,
    ao.all_first_order_date,
    ao.all_last_order_date,
    COALESCE(ao.all_order_total_price, 0) AS all_order_total_price,
    COALESCE(ao.all_order_grand_total, 0) AS all_order_grand_total,
    COALESCE(ao.all_order_net_amount, 0) AS all_order_net_amount,
    COALESCE(ao.all_order_gross_amount, 0) AS all_order_gross_amount,
    COALESCE(ao.all_order_discount_amount, 0) AS all_order_discount_amount,
    COALESCE(ao.all_order_paid_amount, 0) AS all_order_paid_amount,
    COALESCE(ao.all_order_total_qty, 0) AS all_order_total_qty,
    ao.all_first_order_id,
    ao.all_first_order_number,
    ao.all_first_order_at,
    ao.all_first_order_at_vn,
    ao.all_first_order_customer_id,
    ao.all_first_order_customer_name,
    ao.all_first_order_customer_email,
    ao.all_first_order_customer_phone,
    ao.all_first_order_customer_gender,
    ao.all_first_order_customer_age_group,
    ao.all_first_order_customer_default_province,
    ao.all_first_order_customer_default_district,
    ao.all_first_order_customer_rank,
    ao.all_first_order_customer_journey,
    ao.all_first_order_is_repeat_customer,
    ao.all_first_order_sales_person_id,
    ao.all_first_order_sales_person_name,
    ao.all_first_order_sales_region_name,
    ao.all_first_order_sales_city_name,
    ao.all_first_order_sales_store_name,
    ao.all_first_order_sales_position,
    ao.all_first_order_sales_channel,
    ao.all_first_order_sales_channel_raw,
    ao.all_first_order_price_range,
    ao.all_first_order_customer_type,
    ao.all_first_order_payment_status,
    ao.all_first_order_fulfillment_status,
    ao.all_first_order_processing_status,
    ao.all_first_order_location_name,
    ao.all_first_order_assigned_location_name,
    ao.all_first_order_shipping_province,
    ao.all_first_order_shipping_district,
    ao.all_first_order_product_categories,
    ao.all_first_order_purchase_purposes,
    COALESCE(ao.all_order_count, 0) > 0 AS has_order_history,

    fgs.first_order_group_key,
    fgs.first_order_group_at,
    fgs.first_order_group_date,
    COALESCE(fgs.first_order_group_order_count, 0) AS first_order_group_order_count,
    fgs.first_order_group_order_numbers,
    fgs.first_order_group_order_ids,
    COALESCE(fgs.first_order_group_total_price, 0) AS first_order_group_total_price,
    COALESCE(fgs.first_order_group_grand_total, 0) AS first_order_group_grand_total,
    COALESCE(fgs.first_order_group_net_amount, 0) AS first_order_group_net_amount,
    COALESCE(fgs.first_order_group_gross_amount, 0) AS first_order_group_gross_amount,
    COALESCE(fgs.first_order_group_discount_amount, 0) AS first_order_group_discount_amount,
    COALESCE(fgs.first_order_group_paid_amount, 0) AS first_order_group_paid_amount,
    COALESCE(fgs.first_order_group_total_qty, 0) AS first_order_group_total_qty,
    fgs.first_order_id,
    fgs.first_order_number,
    fgs.first_order_at,
    fgs.first_order_at_vn,
    fgs.first_order_date,
    fgs.first_order_customer_id,
    fgs.first_order_customer_name,
    fgs.first_order_customer_email,
    fgs.first_order_customer_phone,
    fgs.first_order_customer_gender,
    fgs.first_order_customer_age_group,
    fgs.first_order_customer_default_province,
    fgs.first_order_customer_default_district,
    fgs.first_order_customer_rank,
    fgs.first_order_customer_journey,
    fgs.first_order_is_repeat_customer,
    fgs.first_order_sales_person_id,
    fgs.first_order_sales_person_name,
    fgs.first_order_sales_region_name,
    fgs.first_order_sales_city_name,
    fgs.first_order_sales_store_name,
    fgs.first_order_sales_position,
    fgs.first_order_sales_channel,
    fgs.first_order_sales_channel_raw,
    fgs.first_order_price_range,
    fgs.first_order_customer_type,
    fgs.first_order_payment_status,
    fgs.first_order_fulfillment_status,
    fgs.first_order_processing_status,
    fgs.first_order_location_name,
    fgs.first_order_assigned_location_name,
    fgs.first_order_shipping_province,
    fgs.first_order_shipping_district,
    fgs.first_order_product_categories,
    fgs.first_order_purchase_purposes,
    COALESCE(fgs.first_order_group_order_count, 0) > 0 AS has_first_order_group
FROM leads l
LEFT JOIN all_order_summary ao
    ON l.lead_id = ao.lead_id
LEFT JOIN first_group_summary fgs
    ON l.lead_id = fgs.lead_id
