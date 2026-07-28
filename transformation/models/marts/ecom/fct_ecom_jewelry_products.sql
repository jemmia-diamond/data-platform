{{ config(
    schema='marts_ecom'
) }}

-- Ecom jewelry products feed — replaces the legacy `ecom.materialized_products` MVIEW. One row
-- per Haravan jewelry product (product_type != 'Nhẫn Cưới', with a design). Carries design
-- attributes, price/quantity aggregates over eligible (non-combo) variants, 360 flag, gold
-- weight, sold quantity and the design's primary collection.
-- NOTE: `pages` filter field is intentionally omitted (no raw source — legacy derived from a
-- dev-made view). `primary_collection_handle` is NULL (design collections carry no handle).
WITH eligible_variants AS (
    SELECT
        v.product_id,
        v.variant_id,
        v.fineness,
        v.qty_onhand,
        v.price                                                       AS raw_price,
        nv.category
    FROM {{ ref('int_catalog__variants') }} v
    LEFT JOIN {{ ref('stg_nocodb__variants') }} nv
        ON nv.haravan_variant_id = v.variant_id
    WHERE v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
),

product_agg AS (
    SELECT
        product_id,
        MIN(raw_price)                                                AS min_price,
        MAX(raw_price)                                                AS max_price,
        MAX(raw_price) FILTER (WHERE fineness ILIKE '%18%')           AS max_price_18,
        MAX(raw_price) FILTER (WHERE fineness ILIKE '%14%')           AS max_price_14,
        COALESCE(SUM(qty_onhand), 0)                                  AS qty_onhand,
        MAX(category)                                                 AS category
    FROM eligible_variants
    GROUP BY product_id
),

product_collections AS (
    SELECT
        entity_id AS product_id,
        jsonb_agg(jsonb_build_object(
            'collection_id', collection_id,
            'title', collection_name,
            'is_excluded', is_excluded,
            'is_active', is_active
        )) AS collections
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'product'
    GROUP BY entity_id
)

SELECT
    p.product_id                                                       AS haravan_product_id,
    p.design_id,
    p.nocodb_product_id                                                AS workplace_id,
    p.title,
    p.handle,
    p.product_type                                                     AS haravan_product_type,
    pa.category,
    d.design_code,
    d.diamond_holder,
    CASE WHEN d.ring_band_type = 'None' THEN NULL ELSE d.ring_band_type END AS ring_band_type,
    d.ring_band_style,
    d.ring_head_style,
    d.main_stone,
    d.stone_quantity,
    d.gender,
    d.shape_of_main_stone,
    d.tag                                                           AS design_tag,
    COALESCE(d.created_date::timestamp, d.created_at)               AS created_date,
    pa.min_price,
    pa.max_price,
    pa.max_price_18,
    pa.max_price_14,
    pa.qty_onhand,
    p.has_360,
    COALESCE(p.estimated_gold_weight, d.gold_weight)                   AS estimated_gold_weight,
    COALESCE(sm.sold_quantity, 0)                                      AS sold_quantity,
    sm.sold_before_2025,
    d.collection_name                                                  AS primary_collection,
    CAST(NULL AS text)                                                 AS primary_collection_handle,
    COALESCE(pc.collections, '[]'::jsonb)                              AS collections,
    p.published_scope

FROM {{ ref('int_catalog__products') }} p
INNER JOIN {{ ref('int_catalog__designs') }} d
    ON d.design_id = p.design_id
LEFT JOIN product_agg pa
    ON pa.product_id = p.product_id
LEFT JOIN {{ ref('int_ecom__sold_metrics') }} sm
    ON sm.product_id = p.product_id
LEFT JOIN product_collections pc
    ON pc.product_id = p.nocodb_product_id

WHERE p.product_type <> 'Nhẫn Cưới'
  AND p.design_id IS NOT NULL
