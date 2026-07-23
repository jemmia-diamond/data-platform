{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya jewelry retouch feed — Haravan products that have a design with a non-empty retouch,
-- enriched with NocoDB design attributes (gender, collection, ring styles, 4view, media) and a JSON
-- array of variants (best active collection deal per variant, price, primary stock location, ring
-- size, material, serial). Grain: 1 row per Haravan product.
WITH best_deal AS (
    SELECT
        entity_id AS product_id,
        discount_type,
        discount_value
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'product' AND best_deal_rank = 1
),

serial_latest AS (
    SELECT DISTINCT ON (variant_id)
        variant_id, storage_size_1, storage_size_2, serial_number
    FROM {{ ref('int_inventory__serials') }}
    ORDER BY variant_id, item_id DESC
),

design_enriched AS (
    SELECT
        np.product_id,
        di.retouch,
        di.images,
        di.videos,
        di.render_images,
        d._4view                                                       AS "4view",
        d.design_code_legacy                                           AS code,
        d.erp_code,
        d.backup_code,
        d.design_code,
        d.diamond_holder,
        d.gender,
        d.collection_name,
        d.ring_band_type,
        d.ring_band_style,
        d.ring_head_style
    FROM {{ ref('int_catalog__products') }} np
    JOIN {{ ref('int_catalog__design_images') }} di
        ON di.design_id = np.design_id
    JOIN {{ ref('int_catalog__designs') }} d
        ON d.design_id = np.design_id
    WHERE di.retouch IS NOT NULL
      AND di.retouch <> '[]'
),

variant_calc AS (
    SELECT
        v.variant_id,
        v.product_id,
        v.variant_title                                          AS title,
        v.price                                                  AS base_price,
        CASE
            WHEN bd.discount_type = 'percent' THEN v.price * (1 - COALESCE(bd.discount_value, 0) / 100)
            WHEN bd.discount_type = 'amount'  THEN v.price - COALESCE(bd.discount_value, 0)
            ELSE v.price
        END                                                       AS sale_price,
        v.ring_size,
        sl.storage_size_1,
        sl.storage_size_2,
        v.fineness,
        v.material_color,
        sl.serial_number,
        bd.discount_type,
        bd.discount_value,
        sv.primary_location_name                                  AS primary_stock_at,
        sv.total_qty
    FROM {{ ref('int_catalog__variants') }} v
    LEFT JOIN best_deal bd
        ON bd.product_id = v.product_id
    LEFT JOIN {{ ref('int_inventory__stock_by_variant') }} sv
        ON sv.variant_id = v.variant_id
    LEFT JOIN serial_latest sl
        ON sl.variant_id = v.variant_id
),

product_variants_agg AS (
    SELECT
        vc.product_id,
        MIN(vc.sale_price)                                        AS min_sale_price,
        SUM(COALESCE(vc.total_qty, 0))                            AS total_product_qty,
        jsonb_agg(jsonb_build_object(
            'id', vc.variant_id::text,
            'title', vc.title,
            'basePrice', vc.base_price,
            'salePrice', vc.sale_price,
            'stockAt', vc.primary_stock_at,
            'ringSize', vc.ring_size,
            'storageSize1', vc.storage_size_1,
            'storageSize2', vc.storage_size_2,
            'fineness', vc.fineness,
            'quantityAvailable', COALESCE(vc.total_qty, 0),
            'materialColor', vc.material_color,
            'serialNumber', vc.serial_number,
            'discountType', vc.discount_type,
            'discountValue', vc.discount_value
        )) AS variants_json,
        array_agg(vc.ring_size) FILTER (WHERE vc.ring_size IS NOT NULL) AS all_ring_sizes,
        array_agg(vc.storage_size_1) FILTER (WHERE vc.storage_size_1 IS NOT NULL) AS all_storage_size_1,
        array_agg(vc.storage_size_2) FILTER (WHERE vc.storage_size_2 IS NOT NULL) AS all_storage_size_2
    FROM variant_calc vc
    WHERE COALESCE(vc.sale_price, vc.base_price) > 0
    GROUP BY vc.product_id
)

SELECT
    p.product_id                                                   AS id,
    p.title,
    p.product_type,
    (
        SELECT jsonb_agg(jsonb_build_object(
            'id', retouch_file ->> 'id',
            'url', retouch_file ->> 'url',
            'size', retouch_file ->> 'size',
            'title', retouch_file ->> 'title',
            'width', retouch_file ->> 'width',
            'height', retouch_file ->> 'height',
            'mimetype', retouch_file ->> 'mimetype'
        ))
        FROM jsonb_array_elements(de.retouch::jsonb) AS retouch_file
    )                                                              AS retouch,
    de.code,
    de.erp_code,
    de.backup_code,
    de.design_code,
    de.diamond_holder,
    de.gender,
    de.collection_name,
    de.ring_band_type,
    de.ring_band_style,
    de.ring_head_style,
    de."4view",
    p.images                                                       AS p_images,
    de.images                                                      AS w_images,
    de.videos                                                      AS w_videos,
    de.render_images,
    COALESCE(pva.variants_json, '[]'::jsonb)                       AS variants,
    pva.min_sale_price,
    pva.total_product_qty,
    p.published_scope,
    pva.all_ring_sizes,
    pva.all_storage_size_1,
    pva.all_storage_size_2

FROM {{ ref('int_catalog__products') }} p
JOIN product_variants_agg pva
    ON pva.product_id = p.product_id
JOIN design_enriched de
    ON de.product_id = p.product_id
