{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fslpp_lead_id ON {{ this }} (lead_id)",
      "CREATE INDEX IF NOT EXISTS idx_fslpp_product_type ON {{ this }} (product_type)",
    ]
) }}

WITH preferred_products AS (
    SELECT * FROM {{ ref('int_crm__lead_preferred_products') }}
),

products AS (
    SELECT lead_product_id, product_type AS product_label
    FROM {{ ref('int_crm__lead_products') }}
)

SELECT
    pp.preferred_product_id,
    pp.lead_id,
    pp.product_type,
    p.product_label,
    pp.idx
FROM preferred_products pp
LEFT JOIN products p
    ON pp.product_type = p.lead_product_id
