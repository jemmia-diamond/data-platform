{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Ecom jewelry variant pricing — final sale price via the legacy worker 3-branch logic
-- (buildJewelryPriceSql). Used by every jewelry list/detail/search API.
--   Branch 1 (active_collection): product is in an active promo collection → final_discount_price
--                                   (fallback to base price when 0/NULL).
--   Branch 2 (direct_discount):    price < compare_at_price → final_discount_price (fallback base).
--   Branch 3 (default_discount):   else → compare_at_price * (100 - ecom_default_jewelry_discount)/100,
--                                   falling back to base price when compare_at_price is 0/NULL
--                                   (compare_at_price is ~always 0 in the synced data, so price is
--                                   the effective list price for most variants).
-- Grain: 1 row per Haravan variant.
WITH active_collection_products AS (
    SELECT DISTINCT entity_id AS product_id
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'product'
      AND is_active
),

priced AS (
    SELECT
        v.variant_id,
        v.product_id,
        v.price                                                AS base_price,
        v.compare_at_price                                     AS price_compare_at,
        v.final_discount_price,
        (acp.product_id IS NOT NULL)                           AS is_in_active_collection,
        CAST(
            CASE
                WHEN acp.product_id IS NOT NULL
                    THEN COALESCE(NULLIF(v.final_discount_price, 0), v.price)
                WHEN v.price < v.compare_at_price
                    THEN COALESCE(NULLIF(v.final_discount_price, 0), v.price)
                ELSE COALESCE(NULLIF(v.compare_at_price, 0) * (100 - {{ var('ecom_default_jewelry_discount', 16) }}) / 100, v.price)
            END AS numeric
        )                                                      AS final_price,
        CASE
            WHEN acp.product_id IS NOT NULL THEN 'active_collection'
            WHEN v.price < v.compare_at_price THEN 'direct_discount'
            ELSE 'default_discount'
        END                                                    AS discount_branch
    FROM {{ ref('int_catalog__variants') }} v
    LEFT JOIN active_collection_products acp
        ON acp.product_id = v.product_id
)

SELECT * FROM priced
