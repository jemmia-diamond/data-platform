{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH haravan_orders AS (
    SELECT * FROM {{ ref('stg_haravan__orders') }}
),

erpnext_orders AS (
    SELECT * FROM {{ ref('stg_erpnext__sales_orders') }}
)

SELECT
    -- Keys
    e.sales_order_id AS erp_sales_order_id,
    h.order_id AS haravan_order_id,
    e.order_number AS erp_order_number,
    h.order_number AS haravan_order_number,

    -- Customer Identity (Unified)
    COALESCE(e.customer_id, h.customer_id::text) AS unified_customer_id,
    e.customer_name,
    COALESCE(e.contact_email, h.contact_email) AS customer_email,
    e.phone AS customer_phone,

    -- Temporal Fields
    h.created_at AS haravan_created_at,
    e.created_at AS erp_created_at,
    e.transaction_date AS business_date, -- Ngày ghi nhận doanh thu chính thức

    -- Financial Metrics (ERPNext là gốc)
    e.total_amount AS gross_amount,
    e.total_taxes_and_charges AS tax_amount,
    e.discount_amount AS erp_discount_amount,
    h.total_discounts AS haravan_discount_amount,
    e.grand_total AS net_amount,
    e.paid_amount,
    e.balance AS outstanding_amount,

    -- Marketing & Source (Haravan là gốc)
    h.channel AS sales_channel,
    h.utm_source,
    h.utm_medium,
    h.utm_campaign,
    h.referring_site,

    -- Status Reconcile
    h.financial_status AS haravan_financial_status,
    e.financial_status AS erp_financial_status,
    e.status AS erp_status,
    e.delivery_status

FROM erpnext_orders e
LEFT JOIN haravan_orders h 
    ON e.haravan_order_id = h.order_id::text
-- Chỉ lấy các đơn đã xác nhận/đã submit trong ERP để tránh đơn nháp
WHERE e.docstatus = 1 
