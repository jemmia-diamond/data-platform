{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["variant_id"]}]
) }}

-- Ecom jewelry variant pricing: the price Haravan charges at checkout.
--
-- Discounts follow the NocoDB links only; a variant without one sells at list price.
-- Rates come from NocoDB haravan_collections.program, never from a constant.
-- Rules, first match wins:
--   list_price (plain chain): product_type 'Dây Chuyền Trơn' → base_price
--   combo: the variant's serial is paired with a diamond → base_price × (1 - combo rate)
--   active_collection: product in a collection whose date window is active now
--     → COALESCE(NULLIF(final_discount_price, 0), collection_price)
--   collection_discount: a collection discount exists → same as above
--   combo_product: another variant of a combo product → base_price × (1 - jewelry_base rate)
--   list_price: no discount link → base_price
--
-- Loose diamonds are priced by the diamond catalog and are left out here.
-- v.price (from int_catalog__variants) = raw Haravan selling price.
-- Grain: 1 row per Haravan variant.

WITH program_rates AS (
    SELECT
        MAX(discount_value) FILTER (WHERE program = 'combo')        AS combo_rate,
        MAX(discount_value) FILTER (WHERE program = 'jewelry_base') AS jewelry_base_rate
    FROM {{ ref('int_catalog__haravan_collections') }}
),

-- Products in active promo collections (date range now).
active_collection_products AS (
    SELECT DISTINCT np.haravan_product_id
    FROM {{ ref('int_catalog__collection_deals') }} cd
    INNER JOIN {{ ref('stg_nocodb__products') }} np
        ON np.product_id = cd.entity_id
    WHERE cd.entity_type = 'product'
      AND cd.is_active
      AND np.haravan_product_id IS NOT NULL
),

-- Variants whose serial is paired with a sellable diamond.
combo_variants AS (
    SELECT DISTINCT wv.variant_id AS nocodb_variant_id
    FROM {{ ref('stg_nocodb__variant_serials_diamonds') }} vsd
    INNER JOIN {{ ref('stg_nocodb__variant_serials') }} vs
        ON vs.serial_id = vsd.serial_id
    INNER JOIN {{ ref('stg_nocodb__variants') }} wv
        ON wv.variant_id = vs.variant_id
    INNER JOIN {{ ref('stg_nocodb__diamonds') }} d
        ON d.diamond_id = vsd.diamond_id
    WHERE d.haravan_variant_id > 0 AND d.haravan_product_id > 0
      AND wv.haravan_variant_id > 0 AND wv.haravan_product_id > 0
),

-- Products with at least one variant in a combo.
combo_products AS (
    SELECT DISTINCT wv.haravan_product_id
    FROM {{ ref('stg_nocodb__variant_serials_diamonds') }} vsd
    INNER JOIN {{ ref('stg_nocodb__variant_serials') }} vs
        ON vs.serial_id = vsd.serial_id
    INNER JOIN {{ ref('stg_nocodb__variants') }} wv
        ON wv.variant_id = vs.variant_id
    WHERE wv.haravan_product_id IS NOT NULL
),

variant_prices AS (
    SELECT
        v.variant_id,
        v.product_id,
        v.product_type,
        v.price                                                   AS base_price,
        v.final_discount_price,
        -- collection_price = price after the product's best collection discount.
        CASE
            WHEN COALESCE(pd.max_discount, 0) > 0
            THEN v.price * (1 - pd.max_discount / 100.0)
            ELSE v.price
        END                                                       AS collection_price,
        (acp.haravan_product_id IS NOT NULL)                      AS is_in_active_collection,
        (cv.nocodb_variant_id IS NOT NULL)                        AS is_combo_variant,
        (cp.haravan_product_id IS NOT NULL)                       AS is_combo_product
    FROM {{ ref('int_catalog__variants') }} v
    LEFT JOIN {{ ref('int_ecom__product_discounts') }} pd
        ON pd.haravan_product_id = v.product_id
    LEFT JOIN active_collection_products acp
        ON acp.haravan_product_id = v.product_id
    LEFT JOIN combo_variants cv
        ON cv.nocodb_variant_id = v.nocodb_variant_id
    LEFT JOIN combo_products cp
        ON cp.haravan_product_id = v.product_id
    WHERE v.diamond_id IS NULL
),

branched AS (
    SELECT
        vp.*,
        r.combo_rate,
        r.jewelry_base_rate,
        CASE
            WHEN vp.product_type = 'Dây Chuyền Trơn' THEN 'list_price'
            WHEN vp.is_combo_variant AND r.combo_rate IS NOT NULL THEN 'combo'
            WHEN vp.is_in_active_collection THEN 'active_collection'
            WHEN vp.collection_price < vp.base_price THEN 'collection_discount'
            WHEN vp.is_combo_product AND r.jewelry_base_rate IS NOT NULL THEN 'combo_product'
            ELSE 'list_price'
        END                                                       AS discount_branch
    FROM variant_prices vp
    CROSS JOIN program_rates r
)

SELECT
    variant_id,
    product_id,
    base_price,
    -- price_compare_at = raw Haravan selling price.
    base_price                                                     AS price_compare_at,
    CAST(
        CASE discount_branch
            WHEN 'combo' THEN base_price * (100 - combo_rate) / 100
            WHEN 'active_collection' THEN COALESCE(NULLIF(final_discount_price, 0), collection_price)
            WHEN 'collection_discount' THEN COALESCE(NULLIF(final_discount_price, 0), collection_price)
            WHEN 'combo_product' THEN base_price * (100 - jewelry_base_rate) / 100
            ELSE base_price
        END AS numeric
    )                                                              AS final_price,
    discount_branch
FROM branched
