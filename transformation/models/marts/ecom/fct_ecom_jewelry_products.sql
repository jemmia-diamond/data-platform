{{ config(
    schema='marts_ecom'
) }}

-- Ecom jewelry products feed — replicates ecom.materialized_products MView 1:1.
-- Source of truth: MView DDL (provided by user).
--
-- Key MView semantics:
--   1. Eligible variants: applique_material IN ('Kim Cương Tự Nhiên','Không Đính Đá','Moissanite') AND price > 0
--   2. Prices computed PER applique_material group, then DISTINCT ON(product) picks ONE material.
--      We pin deterministically to the product's primary applique_material (= lowest-variant_id
--      eligible variant) — the MView's DISTINCT ON is non-deterministic; this is the deterministic pin.
--   3. Earring types ('Bông Tai','Bông Tai Nguyên Chiếc') prices ×2 (sold by pair)
--   4. max_price_18: COALESCE(MAX 18K, MAX 14K) — prefers 18K, falls back to 14K
--   5. max_price_14: COALESCE(MAX 14K, MAX 18K) — prefers 14K, falls back to 18K
--   6. qty_onhand: from ALL Haravan variants (not just eligible)
--   7. sold_quantity: paid + not-cancelled orders, NO earring halving (MView variant)
--   8. primary_collection: first collection (by haravan_id) with a handle
--   9. title: generated from cover + design_type + applique_material + gender
--  10. category: derived from product_type via CASE mapping
--
-- SOURCE: replicates MView using FRESH dlt sources (raw_haravan/raw_nocodb):
--   - primary_collections  -> haravan.collection_product (stg_haravan__collection_product) JOIN
--                            haravan_collections on haravan_id — matches fn exactly.
--   - has_360 / path_to_360 -> workplace.ecom_360 (stg_nocodb__ecom_360) — matches fn exactly.
--   - collections / pages   -> NocoDB products_haravan_collection (fn linked_collections filter).

WITH eligible_variants AS (
    SELECT
        v.product_id,
        v.variant_id,
        v.price,
        hp.product_type,
        nv.applique_material,
        nv.fineness,
        nv.material_color
    FROM {{ ref('int_catalog__variants') }} v
    INNER JOIN {{ ref('stg_haravan__products') }} hp ON hp.product_id = v.product_id
    INNER JOIN {{ ref('stg_nocodb__variants') }} nv ON nv.haravan_variant_id = v.variant_id
    WHERE nv.applique_material IN ('Kim Cương Tự Nhiên', 'Không Đính Đá', 'Moissanite')
      AND v.price > 0
),

-- Primary applique_material per product (= lowest-variant_id eligible variant). Used both for the
-- title and as the deterministic pin for which material's prices/fineness are shown.
product_applique AS (
    SELECT DISTINCT ON (ev.product_id)
        ev.product_id,
        ev.applique_material
    FROM eligible_variants ev
    ORDER BY ev.product_id, ev.variant_id
),

-- Prices computed per (product, applique_material) — replicates the MView's GROUP BY that splits
-- by applique_material.
material_prices AS (
    SELECT
        ev.product_id,
        ev.applique_material,
        CASE WHEN ev.product_type IN {{ ecom_earring_types() }} THEN
            COALESCE(MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 18K'),
                     MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 14K')) * 2
            ELSE COALESCE(MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 18K'),
                          MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 14K'))
        END                                                           AS max_price_18_raw,
        CASE WHEN ev.product_type IN {{ ecom_earring_types() }} THEN
            COALESCE(MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 14K'),
                     MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 18K')) * 2
            ELSE COALESCE(MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 14K'),
                          MAX(ev.price) FILTER (WHERE ev.fineness = 'Vàng 18K'))
        END                                                           AS max_price_14_raw,
        CASE WHEN ev.product_type IN {{ ecom_earring_types() }}
             THEN MIN(ev.price) * 2 ELSE MIN(ev.price) END            AS min_price_raw,
        CASE WHEN ev.product_type IN {{ ecom_earring_types() }}
             THEN MAX(ev.price) * 2 ELSE MAX(ev.price) END            AS max_price_raw,
        STRING_AGG(DISTINCT ev.fineness, ', ')                        AS fineness,
        STRING_AGG(DISTINCT ev.material_color, ', ')                  AS material_colors
    FROM eligible_variants ev
    GROUP BY ev.product_id, ev.applique_material, ev.product_type
),

-- Pick the primary material's price row (DISTINCT ON product pinned to primary applique_material).
product_prices AS (
    SELECT mp.*
    FROM material_prices mp
    INNER JOIN product_applique pa ON pa.product_id = mp.product_id
    WHERE mp.applique_material = pa.applique_material
),

stock AS (
    SELECT product_id, SUM(qty_onhand) AS qty_onhand
    FROM {{ ref('int_catalog__variants') }}
    GROUP BY product_id
),

sold_products AS (
    SELECT li.product_id, SUM(li.quantity) AS sold_quantity
    FROM {{ ref('stg_haravan__order_lines') }} li
    INNER JOIN {{ ref('stg_haravan__orders') }} o ON o.order_id = li.order_id
    WHERE o.cancelled_at IS NULL AND o.financial_status = 'paid'
    GROUP BY li.product_id
),

-- primary_collections (fn haravan.collection_product JOIN haravan_collections on haravan_id).
primary_collections AS (
    SELECT DISTINCT ON (cp.product_id)
        cp.product_id                                                   AS haravan_product_id,
        hc.collection_name                                              AS primary_collection,
        hc.handle                                                       AS primary_collection_handle
    FROM {{ ref('stg_haravan__collection_product') }} cp
    INNER JOIN {{ ref('int_catalog__haravan_collections') }} hc ON hc.haravan_id = cp.collection_id
    WHERE hc.handle IS NOT NULL
      AND cp.product_id IS NOT NULL
    ORDER BY cp.product_id, hc.haravan_id
),

-- Collections per product from NocoDB (= fn workplace.products_haravan_collection).
product_collections AS (
    SELECT
        np.haravan_product_id,
        jsonb_agg(jsonb_build_object(
            'collection_id', hc.collection_id,
            'title', hc.collection_name,
            'handle', hc.handle,
            'is_excluded', hc.is_excluded
        )) AS collections,
        array_agg(DISTINCT hc.handle) FILTER (WHERE hc.handle IS NOT NULL) AS pages
    FROM {{ ref('stg_nocodb__products_haravan_collection') }} phc
    INNER JOIN {{ ref('stg_nocodb__products') }} np ON np.product_id = phc.product_id
    INNER JOIN {{ ref('int_catalog__haravan_collections') }} hc ON hc.collection_id = phc.haravan_collection_id
    GROUP BY np.haravan_product_id
),

-- 360-view availability per NocoDB product (fn workplace.ecom_360).
ecom_360 AS (
    SELECT DISTINCT ON (product_id) product_id
    FROM {{ ref('stg_nocodb__ecom_360') }}
    WHERE product_id IS NOT NULL
    ORDER BY product_id
)


SELECT
    p.product_id                                                       AS haravan_product_id,
    p.product_type                                                     AS haravan_product_type,
    p.handle,
    CASE
        WHEN p.product_type IN ('Nhẫn Nữ', 'Nhẫn Nữ Nguyên Chiếc') THEN 'Nhẫn Nữ'
        WHEN p.product_type IN ('Nhẫn Nam', 'Nhẫn Nam Nguyên Chiếc') THEN 'Nhẫn Nam'
        WHEN p.product_type IN ('Nhẫn Unisex', 'Nhẫn Unisex Nguyên Chiếc') THEN 'Nhẫn Nam'
        WHEN p.product_type IN {{ ecom_earring_types() }} THEN 'Bông Tai'
        WHEN p.product_type IN ('Dây Chuyền Liền Mặt', 'Mặt Dây Chuyền', 'Vòng Cổ') THEN 'Mặt Dây Chuyền'
        WHEN p.product_type IN ('Lắc Tay', 'Vòng Tay') THEN 'Lắc Tay'
        WHEN p.product_type = 'Nhẫn Cưới' THEN 'Nhẫn Cưới'
        WHEN p.product_type = 'Huy Hiệu' THEN 'Huy Hiệu'
        ELSE ''
    END                                                                AS category,
    d.design_code,
    d.design_type,
    d.diamond_holder,
    d.gender,
    CASE WHEN d.ring_band_type = 'None' THEN NULL ELSE d.ring_band_type END AS ring_band_type,
    d.ring_band_style,
    d.ring_head_style,
    d.main_stone,
    d.stone_quantity,
    'Round'::text                                                     AS shape_of_main_stone,
    d.tag                                                               AS design_tag,
    d.wedding_ring_id,
    TRIM(BOTH FROM CONCAT(
        CASE WHEN d.diamond_holder = 'Có ổ chủ' THEN 'Vỏ' ELSE '' END, ' ',
        d.design_type, ' ',
        CASE WHEN pa.applique_material = 'Không Đính Đá' THEN 'Kim Cương Tự Nhiên'
             ELSE COALESCE(pa.applique_material, '') END, ' ',
        COALESCE(d.gender, '')
    ))                                                                 AS title,
    CASE WHEN COALESCE(pd.max_discount, 0) > 0
         THEN pp.max_price_14_raw * (1 - pd.max_discount / 100.0)
         ELSE pp.max_price_14_raw
    END::numeric(15,2)                                                 AS max_price_14,
    CASE WHEN COALESCE(pd.max_discount, 0) > 0
         THEN pp.max_price_18_raw * (1 - pd.max_discount / 100.0)
         ELSE pp.max_price_18_raw
    END::numeric(15,2)                                                 AS max_price_18,
    CASE WHEN COALESCE(pd.max_discount, 0) > 0
         THEN pp.min_price_raw * (1 - pd.max_discount / 100.0)
         ELSE pp.min_price_raw
    END::numeric(15,2)                                                 AS min_price,
    CASE WHEN COALESCE(pd.max_discount, 0) > 0
         THEN pp.max_price_raw * (1 - pd.max_discount / 100.0)
         ELSE pp.max_price_raw
    END::numeric(15,2)                                                 AS max_price,
    st.qty_onhand,
    COALESCE(sp.sold_quantity, 0)                                      AS sold_quantity,
    pcol.primary_collection,
    pcol.primary_collection_handle,
    pp.fineness,
    pp.material_colors,
    p.estimated_gold_weight,
    np.ecom_title,
    np.sold_before_2025,
    p.nocodb_product_id                                                AS workplace_id,
    -- has_360 from ecom_360 (fn workplace.ecom_360 — fresh nocodb source).
    (e.product_id IS NOT NULL)                                         AS has_360,
    CASE WHEN e.product_id IS NOT NULL
         THEN '/jemmia-images/glb/' || d.design_code || '.glb'
         ELSE NULL::text
    END                                                                 AS path_to_360,
    d.design_id,
    d.created_date,
    d.created_at                                                      AS database_created_at,
    p.published_scope,
    COALESCE(pc.collections, '[]'::jsonb)                              AS collections,
    COALESCE(pc.pages, ARRAY[]::text[])                                AS pages

FROM {{ ref('int_catalog__products') }} p
INNER JOIN {{ ref('stg_nocodb__products') }} np ON np.haravan_product_id = p.product_id
INNER JOIN {{ ref('int_catalog__designs') }} d ON d.design_id = p.design_id
INNER JOIN product_applique pa ON pa.product_id = p.product_id
LEFT JOIN product_prices pp ON pp.product_id = p.product_id
LEFT JOIN stock st ON st.product_id = p.product_id
LEFT JOIN sold_products sp ON sp.product_id = p.product_id
LEFT JOIN {{ ref('int_ecom__product_discounts') }} pd ON pd.haravan_product_id = p.product_id
LEFT JOIN primary_collections pcol ON pcol.haravan_product_id = p.product_id
LEFT JOIN product_collections pc ON pc.haravan_product_id = p.product_id
LEFT JOIN ecom_360 e ON e.product_id = p.nocodb_product_id

WHERE p.published_scope IN ('global', 'web')
  AND p.product_type IN (
      'Bông Tai', 'Bông Tai Nguyên Chiếc', 'Dây Chuyền Liền Mặt', 'Lắc Tay',
      'Mặt Dây Chuyền', 'Nhẫn Nam', 'Nhẫn Nữ', 'Nhẫn Nữ Nguyên Chiếc',
      'Nhẫn Nam Nguyên Chiếc', 'Vòng Cổ', 'Vòng Tay', 'Nhẫn Cưới',
      'Dây Chuyền Trơn', 'Huy Hiệu', 'Nhẫn Unisex', 'Nhẫn Unisex Nguyên Chiếc'
  )
  AND p.design_id IS NOT NULL
