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
    modified_by

FROM {{ source('erpnext', 'appointments') }}
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('erpnext', 'deleted_documents') }} dd
    WHERE dd.deleted_doctype = 'Appointment'
      AND (dd.restored IS NULL OR dd.restored = 0)
      AND dd.deleted_name = name
)
