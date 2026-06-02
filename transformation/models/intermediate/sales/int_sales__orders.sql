{{ config(
    materialized='view',
    schema='intermediate',
    meta={
        'depends_on': ['int_haravan__order_ancestry', 'int_erpnext__order_groups']
    }
) }}

-- Unified sales orders: FULL OUTER JOIN Haravan ↔ ERPNext
-- Complex logic (ancestry, split groups) is handled by upstream models.
-- Priority: Haravan first (primary sales system), ERPNext as fallback.

WITH h AS (
    SELECT * FROM {{ ref('stg_haravan__orders') }}
),

e AS (
    SELECT * FROM {{ ref('stg_erpnext__sales_orders') }}
),

ha AS (
    SELECT * FROM {{ ref('int_haravan__order_ancestry') }}
),

eg AS (
    SELECT * FROM {{ ref('int_erpnext__order_groups') }}
)

SELECT
    -- Keys
    COALESCE(e.sales_order_id::text,h.order_id::text) AS unified_sales_order_id,
    COALESCE(h.order_number, e.order_number) AS order_number,
    COALESCE(eg.first_order_at, ha.first_order_at, e.real_order_date::timestamp, h.created_at) AS first_order_at,
    e.sales_order_id AS erp_sales_order_id,
    h.order_id AS haravan_order_id,
    COALESCE(e.split_order_group, h.order_id::text) AS split_order_group,
    COALESCE(e.split_order_group_name, h.order_number) AS split_order_group_name,

    -- Customer
    COALESCE(e.customer_id::text, h.customer_id::text) AS unified_customer_id,
    e.customer_id AS erp_customer_id,
    h.customer_id::text AS haravan_customer_id,
    COALESCE(e.customer_name, h.billing_name ) AS customer_name,
    COALESCE(e.contact_email,h.contact_email ) AS customer_email,
    COALESCE(e.phone, h.billing_phone) AS customer_phone,
    h.staff_user_id AS haravan_staff_user_id,

    -- Order Profile
    COALESCE(h.channel, e.source_name) AS sales_channel,
    e.company,
    COALESCE(h.currency, e.currency) AS currency,
    e.conversion_rate,
    e.selling_price_list,
    e.tax_category,
    e.customer_type as order_customer_type,

    -- Dates
    
    h.created_at AS haravan_created_at,
    e.created_at AS erp_created_at,
    e.transaction_date,
    e.transaction_time,
    e.real_order_date,
    h.confirmed_at AS haravan_confirmed_at,
    h.cancelled_at AS haravan_cancelled_at,
    e.expected_delivery_date,
    e.expected_payment_date,
    e.consultation_date,
    e.fulfillment_completion_date,

    -- Financials (unified)
    COALESCE(h.total_price, e.total_amount) AS gross_amount,
    COALESCE(h.total_line_items_price, e.net_total) AS net_amount,
    COALESCE(h.total_discounts, 0) AS haravan_discount_amount,
    e.discount_amount AS erp_discount_amount,
    e.total_taxes_and_charges AS tax_amount,
    e.grand_total AS erp_grand_total,
    e.rounded_total,
    e.paid_amount,
    e.advance_paid,
    e.balance AS outstanding_amount,
    e.deposit_amount,
    e.deposit_method,
    e.return_amount,

    -- Financials (Haravan raw)
    h.subtotal_price AS haravan_subtotal_price,
    h.total_price AS haravan_total_price,
    h.total_discounts AS haravan_total_discounts,
    h.total_tax AS haravan_total_tax,
    h.total_line_items_price AS haravan_total_line_items_price,

    -- Financials (ERPNext raw)
    e.total AS erp_total,
    e.net_total AS erp_net_total,
    e.total_amount AS erp_total_amount,

    -- Financials (Base Currency)
    e.base_total,
    e.base_net_total,
    e.base_grand_total,
    e.base_discount_amount,

    -- Quantities
    e.total_qty,
    e.total_net_weight,
    h.total_weight AS haravan_total_weight,

    -- Shipping (Haravan primary)
    h.shipping_name,
    h.shipping_phone,
    h.shipping_address1,
    h.shipping_ward,
    h.shipping_district,
    h.shipping_province,
    h.shipping_country,
    h.location_id AS haravan_location_id,
    h.location_name AS haravan_location_name,
    h.assigned_location_name,
    e.delivery_location AS erp_delivery_location,
    e.tracking_number,

    -- Payment
    h.gateway_name,
    h.latest_payment_gateway,
    h.latest_transaction_kind,
    h.latest_transaction_amount,
    e.advance_payment_status,

    -- Marketing (Haravan)
    h.utm_source,
    h.utm_medium,
    h.utm_campaign,
    h.utm_term,
    h.utm_content,
    h.referring_site,
    h.landing_site,
    h.buyer_accepts_marketing,

    -- Statuses
    h.financial_status AS haravan_financial_status,
    e.financial_status AS erp_financial_status,
    e.status AS erp_status,
    e.delivery_status,
    e.billing_status,
    COALESCE(h.latest_fulfillment_status, e.fulfillment_status) AS fulfillment_status,
    h.fulfillment_status AS haravan_fulfillment_status,
    h.closed_status AS haravan_closed_status,
    h.cancelled_status AS haravan_cancelled_status,
    h.confirmed_status AS haravan_confirmed_status,
    h.order_processing_status AS haravan_processing_status,
    h.latest_fulfillment_status AS haravan_latest_fulfillment_status,
    e.carrier_status AS erp_carrier_status,
    h.latest_carrier_status AS haravan_carrier_status,
    e.return_type,

    -- Progress (ERP)
    e.per_billed,
    e.per_delivered,
    e.per_picked,

    -- Loyalty & Commissions (ERP)
    e.total_commission,
    e.commission_rate,
    e.loyalty_amount,
    e.loyalty_points,

    -- Audit
    e.owner,
    e.modified_by,
    e.split_reason,
    e.primary_sales_person,
    h.ref_order_id AS haravan_ref_order_id,
    h.ref_order_number AS haravan_ref_order_number,
    e.is_internal_customer,
    e.is_split_order,
    h.tags AS haravan_tags,
    h.note AS haravan_note,
    e.order_policies,

    -- DLT Metadata
    COALESCE(h._db_updated_at, e._db_updated_at) AS _db_updated_at

FROM h
FULL OUTER JOIN e ON h.order_id::text = e.haravan_order_id
LEFT JOIN ha ON h.order_id = ha.order_id
LEFT JOIN eg ON e.sales_order_id = eg.sales_order_id
