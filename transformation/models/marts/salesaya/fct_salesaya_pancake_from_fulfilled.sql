{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya pancake-from-fulfilled feed (legacy salesaya_get_latest_pancake_id_from_fulfilled_orders)
-- — Pancake conversation/page IDs for leads whose ERPNext sales order flipped to 'Fulfilled' in
-- the last 15 minutes. For each qualifying lead the most recently created linked contact (by its
-- primary lead link) is picked, mirroring the legacy LATERAL ROW_NUMBER = 1 logic but reading the
-- unnested primary_lead_id from int_crm__contacts instead of jsonb_array_elements(links).
-- Grain: 1 row per qualifying lead (latest conversation only).
WITH target_leads AS (
    SELECT DISTINCT c.lead_name
    FROM {{ ref('int_crm__customers') }} c
    JOIN {{ ref('stg_erpnext__sales_orders') }} so
        ON so.customer_id = c.erp_customer_id
    WHERE so.fulfillment_status = 'Fulfilled'
      AND so.updated_at >= NOW() - INTERVAL '15 minutes'
      AND c.lead_name IS NOT NULL
),

contact_mapping AS (
    SELECT
        ct.pancake_conversation_id,
        ct.pancake_page_id,
        ct.primary_lead_id AS lead_id,
        ROW_NUMBER() OVER (
            PARTITION BY ct.primary_lead_id
            ORDER BY ct.created_at DESC
        ) AS rn
    FROM {{ ref('int_crm__contacts') }} ct
    WHERE ct.primary_lead_id IN (SELECT lead_name FROM target_leads)
)

SELECT
    lead_id,
    pancake_conversation_id,
    pancake_page_id
FROM contact_mapping
WHERE rn = 1
  AND pancake_conversation_id IS NOT NULL
