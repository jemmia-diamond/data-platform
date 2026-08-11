{{ config(
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_scheduled_date ON {{ this }} (scheduled_date)",
      "CREATE INDEX IF NOT EXISTS idx_fsa_store ON {{ this }} (store)",
      "CREATE INDEX IF NOT EXISTS idx_fsa_sales_person_id ON {{ this }} (sales_person_id)",
    ]
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
    scheduled_date,
    {{ mask_name('customer_name') }} AS customer_name,
    {{ mask_phone('customer_phone_number') }} AS customer_phone_number,
    {{ mask_email('customer_email') }} AS customer_email,
    gender,
    budget,
    range_estimated_budget,
    purchase_purpose,
    store,
    at_store,
    sales_person_id,
    sales_person_name,
    performed_by,
    notes,
    created_at,
    updated_at,
    owner
FROM {{ ref('int_crm__appointments') }}
