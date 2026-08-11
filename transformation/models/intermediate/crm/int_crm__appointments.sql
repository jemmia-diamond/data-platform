{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT
    appointment_id,
    lead_id,
    party_id,
    appointment_reason,
    appointment_with,
    status,
    order_status,
    scheduled_time,
    scheduled_time::date AS scheduled_date,
    customer_name,
    customer_phone_number,
    customer_email,
    gender,
    budget,
    range_estimated_budget,
    purchase_purpose,
    store,
    at_store,
    primary_sales AS sales_person_id,
    primary_sales_name AS sales_person_name,
    performed_by,
    notes,
    created_at,
    updated_at,
    owner

FROM {{ ref('stg_erpnext__appointments') }}
