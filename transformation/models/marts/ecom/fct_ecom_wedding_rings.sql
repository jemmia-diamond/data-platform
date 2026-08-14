{{ config(
    schema='marts_ecom'
) }}

-- Ecom wedding rings feed — replicates ecom.materialized_wedding_rings MView + fn runtime nesting.
-- Source of truth: MView DDL (provided by user).
--
-- MView valid_wedding_rings filter:
--   published_scope = 'global' (NOT 'web')
--   gender includes BOTH 'Nam' AND 'Nữ' (COUNT DISTINCT gender = 2)
--   design_type = 'Nhẫn Cưới'
--
-- MView aggregation (reads from materialized_products = fct_ecom_jewelry_products):
--   title       = concat('Nhẫn Cưới ', string_agg(DISTINCT design_code, ' / '))
--   max_price   = SUM(member max_price)    [collection-discounted, earring-doubled]
--   min_price   = SUM(member min_price)
--   fineness    = string_agg(DISTINCT ..., ', ') after unnesting member fineness strings
--   qty_onhand  = SUM(member qty_onhand)
--   sold_quantity = SUM(member sold_quantity)
--
-- fn runtime adds per-product JSON with variants — price from ecom.variants view semantics:
--   price           = final_price (3-branch discounted, same as fct_ecom_jewelry_variants.price)
--   compare_at_price = price_compare_at = raw Haravan selling price (giá gốc)
--   (NOT raw haravan compare_at_price — that is 0 for 99.9% of variants.)
-- fineness/material_colors are comma-separated TEXT (not arrays) — BFF must use LIKE ANY for filtering.

WITH valid_wedding_rings AS (
    SELECT d.wedding_ring_id AS id
    FROM {{ ref('int_catalog__designs') }} d
    INNER JOIN {{ ref('int_catalog__products') }} p ON p.design_id = d.design_id
    INNER JOIN {{ ref('stg_haravan__products') }} hp ON hp.product_id = p.product_id
    WHERE hp.published_scope = 'global'
      AND d.gender IN ('Nam', 'Nữ')
      AND d.design_type = 'Nhẫn Cưới'
      AND d.wedding_ring_id IS NOT NULL
    GROUP BY d.wedding_ring_id
    HAVING COUNT(DISTINCT d.gender) = 2
),

member_products AS (
    SELECT
        d.wedding_ring_id,
        p.product_id,
        p.product_type,
        COALESCE(np.ecom_title, p.title)  AS title,
        p.handle,
        CASE WHEN d.ring_band_type = 'None' THEN NULL ELSE d.ring_band_type END AS ring_band_type,
        d.design_code,
        d.diamond_holder,
        d.gender,
        d.ring_band_style,
        COALESCE(d.created_date::timestamp, d.created_at)               AS created_date,
        p.images
    FROM valid_wedding_rings vwr
    INNER JOIN {{ ref('int_catalog__designs') }} d ON d.wedding_ring_id = vwr.id
                                                  AND d.design_type = 'Nhẫn Cưới'
                                                  AND d.gender IN ('Nam', 'Nữ')
    INNER JOIN {{ ref('int_catalog__products') }} p ON p.design_id = d.design_id
    INNER JOIN {{ ref('stg_haravan__products') }} hp ON hp.product_id = p.product_id
                                                    AND hp.published_scope = 'global'
    INNER JOIN {{ ref('fct_ecom_jewelry_products') }} fp ON fp.haravan_product_id = p.product_id
    LEFT JOIN {{ ref('stg_nocodb__products') }} np ON np.haravan_product_id = p.product_id
),

member_aggregates AS (
    SELECT
        mp.wedding_ring_id,
        SUM(fp.max_price)                                                 AS max_price,
        SUM(fp.min_price)                                                 AS min_price,
        SUM(fp.qty_onhand)                                                AS qty_onhand,
        SUM(fp.sold_quantity)                                             AS sold_quantity,
        STRING_AGG(DISTINCT mp.design_code, ' / ')                        AS design_codes,
        -- unnest member fineness/material_colors comma-strings then re-aggregate
        STRING_AGG(DISTINCT fv.fineness_val, ', ')                        AS fineness,
        STRING_AGG(DISTINCT mv.material_val, ', ')                        AS material_colors
    FROM member_products mp
    LEFT JOIN {{ ref('fct_ecom_jewelry_products') }} fp ON fp.haravan_product_id = mp.product_id
    CROSS JOIN LATERAL unnest(string_to_array(fp.fineness, ', ')) AS fv(fineness_val)
    CROSS JOIN LATERAL unnest(string_to_array(fp.material_colors, ', ')) AS mv(material_val)
    GROUP BY mp.wedding_ring_id
),

variant_json AS (
    SELECT
        mp.wedding_ring_id,
        mp.product_id,
        jsonb_agg(
            jsonb_build_object(
                'id', v.variant_id,
                'fineness', v.fineness,
                'material_color', v.material_color,
                'ring_size', v.ring_size,
                'price', pr.final_price,
                'compare_at_price', pr.price_compare_at,
                'inventory_quantity', v.qty_available,
                'title', v.variant_title,
                'available', v.qty_available > 0
            )
        ) AS variants
    FROM member_products mp
    INNER JOIN {{ ref('int_catalog__variants') }} v ON v.product_id = mp.product_id
    INNER JOIN {{ ref('int_ecom__jewelry_variant_prices') }} pr ON pr.variant_id = v.variant_id
    GROUP BY mp.wedding_ring_id, mp.product_id
)

SELECT
    mp.wedding_ring_id                                                  AS id,
    CONCAT('Nhẫn Cưới ', ma.design_codes)                               AS title,
    ma.max_price,
    ma.min_price,
    ma.qty_onhand,
    ma.sold_quantity,
    ma.fineness,
    ma.material_colors,
    jsonb_agg(
        jsonb_build_object(
            'id', mp.product_id,
            'product_type', mp.product_type,
            'title', mp.title,
            'ring_band_type', mp.ring_band_type,
            'design_code', mp.design_code,
            'diamond_holder', mp.diamond_holder,
            'gender', mp.gender,
            'handle', mp.handle,
            'variants', vj.variants,
            'images', COALESCE(
                (SELECT array_agg(elem ->> 'src' ORDER BY (elem ->> 'position')::int NULLS LAST)
                 FROM jsonb_array_elements(mp.images::jsonb) elem),
                ARRAY[]::text[]
            )
        )
    )                                                                   AS products

FROM member_products mp
INNER JOIN member_aggregates ma ON ma.wedding_ring_id = mp.wedding_ring_id
INNER JOIN variant_json vj ON vj.wedding_ring_id = mp.wedding_ring_id
                            AND vj.product_id = mp.product_id
GROUP BY
    mp.wedding_ring_id,
    ma.max_price, ma.min_price, ma.qty_onhand, ma.sold_quantity,
    ma.fineness, ma.material_colors, ma.design_codes
