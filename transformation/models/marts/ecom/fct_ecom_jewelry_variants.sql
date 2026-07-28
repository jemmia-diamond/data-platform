{{ config(
    materialized='materialized_view',
    schema='marts_ecom'
) }}

-- Ecom jewelry variants feed — replaces the legacy `ecom.materialized_variants` MVIEW. One row
-- per Haravan variant of a jewelry product (product_type != 'Nhẫn Cưới', with a design),
-- excluding diamond-combo variants (excludeSerialsDiamonds). Carries price (base + computed
-- final_discount_price), material/fineness/ring attributes and stock quantities.
SELECT
    v.product_id                                                       AS haravan_product_id,
    v.variant_id                                                       AS haravan_variant_id,
    v.sku,
    v.price,
    v.compare_at_price                                                 AS price_compare_at,
    pr.final_price                                                     AS final_discount_price,
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
    COALESCE(dic.images, ARRAY[]::text[])                              AS images

FROM {{ ref('int_catalog__variants') }} v
INNER JOIN {{ ref('int_ecom__jewelry_variant_prices') }} pr
    ON pr.variant_id = v.variant_id
INNER JOIN {{ ref('int_catalog__products') }} p
    ON p.product_id = v.product_id
INNER JOIN {{ ref('int_catalog__designs') }} d
    ON d.design_id = p.design_id
LEFT JOIN {{ ref('stg_nocodb__variants') }} nv
    ON nv.haravan_variant_id = v.variant_id
LEFT JOIN {{ ref('int_ecom__design_images_cdn') }} dic
    ON dic.design_id = p.design_id
   AND dic.material_color = v.material_color

WHERE p.product_type <> 'Nhẫn Cưới'
  AND p.design_id IS NOT NULL
  AND v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
