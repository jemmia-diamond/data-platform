{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    -- Primary Key
    name AS appointment_id,

    -- Parent link (the Lead this appointment is attached to)
    lead AS lead_id,
    party AS party_id,

    -- Content
    appointment_reason,
    appointment_with,
    status,
    order_status,
    scheduled_time::timestamp AS scheduled_time,

    -- Customer info
    customer_name,
    customer_phone_number,
    customer_email,
    gender,

    -- Budget
    budget,
    range_estimated_budget,
    purchase_purpose,

    -- Store & sales
    store,
    at_store,
    primary_sales,
    primary_sales_name,
    performed_by,
    notes,

    -- Flags & Configuration
    docstatus::int AS docstatus,
    idx::int AS idx,

    -- Timestamps
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by,

    -- Linked Sales Order (appended at end for CREATE OR REPLACE VIEW compatibility)
    sales_order AS erp_sales_order_id,

    -- Linked order group, resolved by ERPNext (appended at end for CREATE OR REPLACE VIEW compatibility)
    e_order AS erp_order_number,
    sales_order_group_names AS erp_order_group_names,
    group_order_grand_total::numeric AS erp_group_order_grand_total

FROM {{ source('erpnext', 'appointments') }}
WHERE name not in (
    SELECT deleted_name
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Appointment'
      AND (dd.restored IS NULL OR dd.restored = 0)
    --   AND dd.deleted_name = name
)
