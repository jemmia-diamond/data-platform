{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["variant_id"]}]
) }}

-- Ecom jewelry variant pricing — replicates materialized_variants + fn buildJewelryPriceSql.
--
-- MView materialized_variants defines two price columns from raw Haravan vv.price:
--   price             = vv.price × (1 - max_collection_discount/100)  [collection-discounted]
--   price_compare_at  = vv.price                                       [raw selling price]
--
-- fn buildJewelryPriceSql reads those MView columns (3-branch CASE, first match wins):
--   Branch 1 (active_collection): product in a Haravan collection whose date-window is active now
--     → COALESCE(NULLIF(final_discount_price, 0), collection_price)
--   Branch 2 (collection_discount): collection_price < base_price (a collection discount exists)
--     → COALESCE(NULLIF(final_discount_price, 0), collection_price)
--   Branch 3 (default_discount): no collection discount at all
--     → base_price × (100 - ecom_default_jewelry_discount) / 100
--
-- In dbt, v.price (from int_catalog__variants) = raw Haravan selling price = MView's price_compare_at.
-- We COMPUTE collection_price = v.price × (1 - discount/100) = MView's price column.
--
-- Grain: 1 row per Haravan variant.

-- Max collection discount per Haravan product (matches MView discount_info subquery).
WITH collection_max_discount AS (
    SELECT
        np.haravan_product_id,
        MAX(cd.discount_value)                                    AS max_discount
    FROM {{ ref('int_catalog__collection_deals') }} cd
    INNER JOIN {{ ref('stg_nocodb__products') }} np
        ON np.product_id = cd.entity_id
    WHERE cd.entity_type = 'product'
      AND cd.discount_type IS NOT NULL
      AND cd.discount_type <> ''
      AND np.haravan_product_id IS NOT NULL
    GROUP BY np.haravan_product_id
),

-- Products in active promo collections (date range now — matches fn EXISTS check).
active_collection_products AS (
    SELECT DISTINCT np.haravan_product_id
    FROM {{ ref('int_catalog__collection_deals') }} cd
    INNER JOIN {{ ref('stg_nocodb__products') }} np
        ON np.product_id = cd.entity_id
    WHERE cd.entity_type = 'product'
      AND cd.is_active
      AND np.haravan_product_id IS NOT NULL
),

variant_prices AS (
    SELECT
        v.variant_id,
        v.product_id,
        v.price                                                   AS base_price,
        v.final_discount_price,
        -- collection_price = MView's price column (collection-discounted).
        CASE
            WHEN COALESCE(cmd.max_discount, 0) > 0
            THEN v.price * (1 - cmd.max_discount / 100.0)
            ELSE v.price
        END                                                       AS collection_price,
        (acp.haravan_product_id IS NOT NULL)                      AS is_in_active_collection
    FROM {{ ref('int_catalog__variants') }} v
    LEFT JOIN collection_max_discount cmd
        ON cmd.haravan_product_id = v.product_id
    LEFT JOIN active_collection_products acp
        ON acp.haravan_product_id = v.product_id
)

SELECT
    variant_id,
    product_id,
    base_price,
    -- price_compare_at = raw Haravan selling price (= MView price_compare_at = vv.price).
    base_price                                                     AS price_compare_at,
    CAST(
        CASE
            WHEN is_in_active_collection
                THEN COALESCE(NULLIF(final_discount_price, 0), collection_price)
            WHEN collection_price < base_price
                THEN COALESCE(NULLIF(final_discount_price, 0), collection_price)
            ELSE base_price * (100 - {{ var('ecom_default_jewelry_discount', 16) }}) / 100
        END AS numeric
    )                                                              AS final_price,
    CASE
        WHEN is_in_active_collection THEN 'active_collection'
        WHEN collection_price < base_price THEN 'collection_discount'
        ELSE 'default_discount'
    END                                                            AS discount_branch
FROM variant_prices
