{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH haravan_items AS (
    SELECT * FROM {{ ref('stg_haravan__order_lines') }}
),

erpnext_items AS (
    SELECT * FROM {{ ref('stg_erpnext__sales_order_items') }}
)

SELECT
    -- Keys
    e.sales_order_item_id,
    e.sales_order_id AS erp_sales_order_id,
    e.sku,
    e.item_name,
    e.haravan_variant_id,

    -- Product Details (Jemmia Jewelry Specific)
    e.serial_numbers,
    e.diamond_details,
    e.total_weight,
    e.weight_uom,

    -- Quantities
    e.qty AS erp_qty,
    h.quantity AS haravan_qty,
    e.delivered_qty,

    -- Financials (Transaction Currency)
    e.rate AS unit_price,
    e.amount AS line_total,
    e.net_amount AS line_net_total,
    e.discount_amount AS line_discount_amount,
    e.valuation_rate AS unit_cost, 

    -- Status & Metadata
    e.warehouse,
    e.item_type,
    e.transaction_date

FROM erpnext_items e
LEFT JOIN haravan_items h 
    ON e.haravan_variant_id = h.variant_id
    -- Filter to ensure we only join items belonging to the same logical order if possible
    -- However, haravan_order_id isn't directly in erpnext_items, it's in the parent.
    -- For now, variant_id match is the primary link.
