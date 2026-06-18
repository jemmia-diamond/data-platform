{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot lead preferred products bridge. Grain: 1 row = 1 lead × 1 preferred product type.
-- Source: int_crm__lead_preferred_products.
-- No allocation needed (leads have no direct revenue).
-- NOTE: preferred_product is a product_type string (free-text categorical), NOT a product_key.
-- It does NOT FK to dim_metabot_products.

WITH preferred_products AS (
    SELECT * FROM {{ ref('int_crm__lead_preferred_products') }}
),

products AS (
    SELECT lead_product_id, product_type AS product_label
    FROM {{ ref('int_crm__lead_products') }}
)

SELECT DISTINCT
    pp.lead_id || ':' || pp.product_type AS preferred_link_id,
    pp.lead_id,
    pp.product_type,
    p.product_label AS preferred_product_name
FROM preferred_products pp
LEFT JOIN products p
    ON pp.product_type = p.lead_product_id
WHERE pp.product_type IS NOT NULL
