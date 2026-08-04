{{ config(
    schema='marts_ecom'
) }}

-- Ecom jewelry variants feed — replicates materialized_variants MView + runtime filters.
--
-- MView materialized_variants eligibility (pre-filter):
--   applique_material IN ('Kim Cương Tự Nhiên', 'Không Đính Đá')  (NOT Moissanite — MView variants stricter)
--   fineness IN ('Vàng 18K', 'Vàng 14K')
--   vv.price > 0
--   published_scope IN ('global', 'web')
--   product_type whitelist (same as products MView)
--
-- Runtime additions (fn buildQueryV2):
--   excludeSerialsDiamonds (NOT EXISTS variant_serials_diamonds)
--   product_type != 'Nhẫn Cưới' (jewelry list excludes wedding rings)
--   cardinality(design_imgs.images) > 0 (image presence per material_color)
--
-- MView price columns:
--   price             = vv.price × (1 - max_collection_discount/100)  [collection-discounted]
--   price_compare_at  = vv.price                                       [raw]
--
-- fn buildJewelryPriceSql produces the final display price from those columns (see int_ecom__jewelry_variant_prices).

SELECT
    v.product_id                                                       AS haravan_product_id,
    v.variant_id                                                       AS haravan_variant_id,
    v.sku,
    pr.final_price                                                     AS price,
    pr.price_compare_at,
    pr.discount_branch,
    v.material_color,
    v.fineness,
    v.ring_size,
    v.qty_available,
    v.qty_onhand,
    nv.applique_material,
    v.estimated_gold_weight,
    d.ring_band_style,
    d.ring_head_style,
    COALESCE(dic.images, ARRAY[]::text[])                              AS images,
    COALESCE(
        CASE WHEN dm.diamond_variant_id IS NOT NULL THEN jsonb_build_array(dm.diamond_json) END,
        '[]'::jsonb
    )                                                                  AS diamonds

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

WHERE p.product_type <> 'Nhẫn Cưới'
  AND p.design_id IS NOT NULL
  AND v.price > 0
  -- MView variant eligibility (materialized_variants pre-filter)
  AND nv.applique_material IN ('Kim Cương Tự Nhiên', 'Không Đính Đá')
  AND nv.fineness IN ('Vàng 18K', 'Vàng 14K')
  -- Runtime: exclude serial-diamond combo variants
  AND v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
