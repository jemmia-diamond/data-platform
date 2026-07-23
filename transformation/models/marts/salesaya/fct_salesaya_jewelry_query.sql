{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya product feed — Haravan products (excluding loose 'Round'/'Pear' stones) enriched with
-- NocoDB design attributes, best available collection deal, and a JSON array of in-stock variants
-- (per-warehouse pricing, discount, quantity, serial numbers, sold flag). Only products with at least
-- one in-stock variant are included. Grain: 1 row per Haravan product.
--
-- Performance: variant x warehouse rows are flattened ONCE (no per-product correlated lateral),
-- then aggregated per product.
WITH best_deal AS (
    SELECT
        entity_id AS product_id,
        discount_type,
        discount_value
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'product' AND best_deal_rank = 1
),

-- Pre-aggregated serial lookups (single scans, joined — no correlated laterals).
serial_latest AS (
    SELECT DISTINCT ON (variant_id)
        variant_id, storage_size_1, storage_size_2
    FROM {{ ref('int_inventory__serials') }}
    ORDER BY variant_id, item_id DESC
),

serials_by_loc AS (
    SELECT
        variant_id,
        stock_location,
        jsonb_agg(serial_number) AS list
    FROM {{ ref('int_inventory__serials') }}
    GROUP BY variant_id, stock_location
),

variant_rows AS (
    SELECT
        v.product_id,
        v.variant_id,
        v.price,
        v.barcode,
        v.ring_size,
        v.fineness,
        v.material_color,
        il.location_id,
        il.location_name,
        il.qty_available,
        sl.storage_size_1,
        sl.storage_size_2,
        sbl.list AS serial_numbers,
        (sold.variant_id IS NOT NULL) AS exist_in_line_items
    FROM {{ ref('int_catalog__variants') }} v
    JOIN {{ ref('int_inventory__stock_by_location') }} il
        ON il.variant_id = v.variant_id
    LEFT JOIN {{ ref('int_sales__sold_variants') }} sold
        ON sold.variant_id = v.variant_id
       AND sold.product_id = v.product_id
    LEFT JOIN serial_latest sl
        ON sl.variant_id = v.variant_id
    LEFT JOIN serials_by_loc sbl
        ON sbl.variant_id = v.variant_id
       AND sbl.stock_location = il.location_name
    WHERE il.qty_available >= 0
),

product_variants AS (
    SELECT
        vr.product_id,
        SUM(vr.qty_available) AS total_qty,
        json_agg(json_build_object(
            'id', vr.location_id,
            'name', vr.location_name,
            'qty_available', vr.qty_available,
            'discountType', bd.discount_type,
            'discountValue', bd.discount_value,
            'basePrice', vr.price,
            'barCode', vr.barcode,
            'salePrice',
                CASE
                    WHEN bd.discount_type = 'percent' THEN vr.price * (1 - COALESCE(bd.discount_value, 0) / 100)
                    WHEN bd.discount_type = 'amount'  THEN vr.price - COALESCE(bd.discount_value, 0)
                    ELSE vr.price
                END,
            'quantity', vr.qty_available,
            'ringSize', vr.ring_size,
            'storageSize1', vr.storage_size_1,
            'storageSize2', vr.storage_size_2,
            'fineness', vr.fineness,
            'materialColor', vr.material_color,
            'serialNumbers', COALESCE(vr.serial_numbers, '[]'::jsonb),
            'exist_in_line_items', vr.exist_in_line_items
        )) AS variants_json
    FROM variant_rows vr
    LEFT JOIN best_deal bd
        ON bd.product_id = vr.product_id
    GROUP BY vr.product_id
)

SELECT DISTINCT ON (p.product_id)
    p.product_id                                                   AS id,
    p.title,
    p.product_type,
    di.retouch::json                                               AS retouch,
    d.design_code_legacy                                           AS code,
    d.erp_code,
    d.backup_code,
    d.design_code,
    p.images                                                       AS p_images,
    di.images,
    di.render_images,
    di.videos,
    d._4view                                                       AS "4view",
    d.diamond_holder,
    d.gender,
    d.collection_name,
    d.ring_band_type,
    d.ring_band_style,
    d.ring_head_style,
    p.published_scope,
    bd.discount_type,
    bd.discount_value,
    p.nocodb_product_id                                            AS "wpId",
    COALESCE(pv.total_qty, 0)                                      AS "totalQuantity",
    pv.variants_json                                               AS variants

FROM {{ ref('int_catalog__products') }} p
LEFT JOIN {{ ref('int_catalog__design_images') }} di
    ON di.design_id = p.design_id
LEFT JOIN {{ ref('int_catalog__designs') }} d
    ON d.design_id = p.design_id
LEFT JOIN best_deal bd
    ON bd.product_id = p.product_id
LEFT JOIN product_variants pv
    ON pv.product_id = p.product_id

WHERE p.product_type NOT IN ('Round', 'Pear')
  AND p.design_id IS NOT NULL
  AND pv.variants_json IS NOT NULL
  AND pv.variants_json::text <> '[]'
ORDER BY p.product_id
