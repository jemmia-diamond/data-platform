{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Sold variants — source of truth for "has this variant/product ever appeared in a sale".
-- Derived from Haravan order lines. Used to flag whether a catalog item has been sold.
-- Grain: 1 row per distinct (variant_id, product_id) that has been sold.
SELECT DISTINCT
    variant_id,
    product_id
FROM {{ ref('stg_haravan__order_lines') }}
WHERE variant_id IS NOT NULL
  AND product_id IS NOT NULL
