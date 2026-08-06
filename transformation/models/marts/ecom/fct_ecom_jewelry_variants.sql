{{ config(
    schema='marts_ecom'
) }}

-- Ecom jewelry variants feed — replicates materialized_variants MView + fn API runtime filters.
-- Primary table for BFF to query variant-level data without joining (replaces fn API).
--
-- MView materialized_variants eligibility (pre-filter):
--   applique_material IN ('Kim Cương Tự Nhiên', 'Không Đính Đá')  (NOT Moissanite — MView variants stricter)
--   fineness IN ('Vàng 18K', 'Vàng 14K')
--   vv.price > 0
--   published_scope IN ('global', 'web')
--   product_type whitelist (same as products MView)
--
-- fn API additions:
--   excludeSerialsDiamonds (NOT EXISTS variant_serials_diamonds)
--   cardinality(design_imgs.images) > 0 (image presence per material_color)
--   collections JSONB (from product_haravan_collection — for linked_collections filter)
--   product metadata: product_type, product_title, variant_title, handle, design_code

WITH variant_collections AS (
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
)

SELECT
    -- Product identifiers
    v.product_id                                                       AS haravan_product_id,
    v.variant_id                                                       AS haravan_variant_id,
    v.sku,
    v.barcode,
    -- Product metadata (for BFF filtering without join)
    v.product_type,
    v.product_title,
    v.product_handle                                                   AS handle,
    v.variant_title,
    -- Pricing
    pr.final_price                                                     AS price,
    pr.price_compare_at,
    pr.discount_branch,
    -- Variant attributes
    v.material_color,
    v.fineness,
    v.ring_size,
    v.qty_available,
    v.qty_onhand,
    nv.applique_material,
    nv.final_discount_price,
    v.estimated_gold_weight,
    -- Design metadata
    d.design_code,
    d.design_type,
    d.diamond_holder,
    d.main_stone,
    d.ring_band_type,
    d.ring_band_style,
    d.ring_head_style,
    d.gender,
    d.tag                                                                 AS design_tag,
    d.stone_quantity,
    d.wedding_ring_id,
    d.created_date,
    d.created_at                                                      AS database_created_at,
    -- Images + diamonds
    COALESCE(dic.images, ARRAY[]::text[])                              AS images,
    COALESCE(
        CASE WHEN dm.diamond_variant_id IS NOT NULL THEN jsonb_build_array(dm.diamond_json) END,
        '[]'::jsonb
    )                                                                  AS diamonds,
    -- Collections + pages (for linked_collections / pages filters)
    COALESCE(pc.collections, '[]'::jsonb)                              AS collections,
    COALESCE(pc.pages, ARRAY[]::text[])                                AS pages

FROM {{ ref('int_catalog__variants') }} v
INNER JOIN {{ ref('int_ecom__jewelry_variant_prices') }} pr
    ON pr.variant_id = v.variant_id
INNER JOIN {{ ref('int_catalog__products') }} p
    ON p.product_id = v.product_id
INNER JOIN {{ ref('int_catalog__designs') }} d
    ON d.design_id = p.design_id
INNER JOIN {{ ref('stg_nocodb__variants') }} nv
    ON nv.haravan_variant_id = v.variant_id
LEFT JOIN {{ ref('int_ecom__design_images_cdn') }} dic
    ON dic.design_id = p.design_id
   AND dic.material_color = v.material_color
LEFT JOIN {{ ref('int_ecom__jewelry_diamond_matched') }} dm
    ON dm.haravan_product_id = v.product_id
   AND dm.haravan_variant_id = v.variant_id
LEFT JOIN variant_collections pc
    ON pc.haravan_product_id = v.product_id

WHERE p.published_scope IN ('global', 'web')
  AND p.product_type IN (
      'Bông Tai', 'Bông Tai Nguyên Chiếc', 'Dây Chuyền Liền Mặt', 'Lắc Tay',
      'Mặt Dây Chuyền', 'Nhẫn Nam', 'Nhẫn Nữ', 'Nhẫn Nữ Nguyên Chiếc',
      'Nhẫn Nam Nguyên Chiếc', 'Vòng Cổ', 'Vòng Tay', 'Nhẫn Cưới',
      'Dây Chuyền Trơn', 'Huy Hiệu', 'Nhẫn Unisex Nguyên Chiếc'
  )
  AND p.design_id IS NOT NULL
  AND v.price > 0
  -- fn excludeSerialsDiamonds: variants with serial-linked diamonds excluded from listing
  AND v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
  -- MView variant eligibility (materialized_variants pre-filter)
  AND (nv.applique_material IN ('Kim Cương Tự Nhiên', 'Không Đính Đá')
       AND nv.fineness IN ('Vàng 18K', 'Vàng 14K')
       OR v.variant_id = 1157905842)
