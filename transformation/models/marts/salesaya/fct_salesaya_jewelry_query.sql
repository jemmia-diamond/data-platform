{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH best_deal AS (
    SELECT DISTINCT ON (product_collection_links.product_id)
        product_collection_links.product_id,
        haravan_collections.discount_type,
        haravan_collections.discount_value
    FROM {{ ref('stg_nocodb__products_haravan_collection') }} AS product_collection_links
    JOIN {{ ref('stg_nocodb__haravan_collections') }} AS haravan_collections
        ON haravan_collections.haravan_collection_id = product_collection_links.haravan_collection_id
    ORDER BY product_collection_links.product_id, haravan_collections.discount_value DESC NULLS LAST
)

SELECT DISTINCT ON (haravan_products.product_id)
    haravan_products.product_id                                          AS id,
    haravan_products.title,
    haravan_products.product_type,
    design_images.retouch::json                                         AS retouch,
    designs.design_code_legacy                                          AS code,
    designs.erp_code,
    designs.backup_code,
    designs.design_code,
    haravan_products.images                                             AS p_images,

    -- design_images.images / render_images / videos are not ingested
    -- (design_design_images only exposes id, design_id, material_color, retouch, ...).
    -- design_images.images,
    -- design_images.render_images,
    -- design_images.videos,

    -- designs."4view" is not ingested (not in the NocoDB designs field list).
    -- designs."4view",

    designs.diamond_holder,
    best_deal.discount_type,
    best_deal.discount_value,
    nocodb_products.product_id                                          AS "wpId",
    COALESCE(variant_data.total_qty, 0)                                 AS "totalQuantity",
    variant_data.variants_json                                          AS variants

FROM {{ ref('stg_haravan__products') }} AS haravan_products
JOIN {{ ref('stg_nocodb__products') }} AS nocodb_products
    ON nocodb_products.haravan_product_id = haravan_products.product_id
LEFT JOIN {{ ref('stg_nocodb__design_design_images') }} AS design_images
    ON design_images.design_id = nocodb_products.design_id
LEFT JOIN {{ ref('stg_nocodb__designs') }} AS designs
    ON designs.design_id = nocodb_products.design_id
LEFT JOIN best_deal
    ON best_deal.product_id = nocodb_products.product_id
LEFT JOIN LATERAL (
    SELECT
        SUM(inventory_locations.qty_available) AS total_qty,
        json_agg(json_build_object(
            'id', locations.location_id,
            'name', locations.name,
            'qty_available', inventory_locations.qty_available,
            'discountType', best_deal.discount_type,
            'discountValue', best_deal.discount_value,
            'basePrice', haravan_variants.price,
            'barCode', haravan_variants.barcode,
            'salePrice',
                CASE
                    WHEN best_deal.discount_type = 'percent' THEN haravan_variants.price * (1 - COALESCE(best_deal.discount_value, 0) / 100)
                    WHEN best_deal.discount_type = 'amount'  THEN haravan_variants.price - COALESCE(best_deal.discount_value, 0)
                    ELSE haravan_variants.price
                END,
            'quantity', inventory_locations.qty_available,
            'ringSize', nocodb_variants.ring_size,
            -- storageSize1 / storageSize2 are not ingested (not in the NocoDB variant_serials field list).
            -- 'storageSize1', variant_serials_agg.storage_size_1,
            -- 'storageSize2', variant_serials_agg.storage_size_2,
            'fineness', nocodb_variants.fineness,
            'materialColor', nocodb_variants.material_color,
            'serialNumbers', COALESCE(serials.list, '[]'::jsonb),
            'exist_in_line_items', EXISTS (
                SELECT 1
                FROM {{ ref('stg_haravan__order_lines') }} AS order_lines
                WHERE order_lines.variant_id = haravan_variants.variant_id
                  AND order_lines.product_id = haravan_products.product_id
            )
        )) AS variants_json
    FROM {{ ref('stg_haravan__product_variants') }} AS haravan_variants
    JOIN {{ ref('stg_haravan__inventory_locations') }} AS inventory_locations
        ON inventory_locations.variant_id = haravan_variants.variant_id
    LEFT JOIN {{ ref('stg_haravan__locations') }} AS locations
        ON locations.location_id = inventory_locations.location_id
    LEFT JOIN {{ ref('stg_nocodb__variants') }} AS nocodb_variants
        ON nocodb_variants.product_id = nocodb_products.product_id
       AND nocodb_variants.sku = haravan_variants.sku::text
    -- LEFT JOIN {{ ref('stg_nocodb__variant_serials') }} AS variant_serials_agg
    --     ON variant_serials_agg.variant_id = nocodb_variants.variant_id
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(variant_serials.serial_number) AS list
        FROM {{ ref('stg_nocodb__variant_serials') }} AS variant_serials
        WHERE variant_serials.variant_id = nocodb_variants.variant_id
          AND variant_serials.stock_at = locations.name
    ) AS serials ON true
    WHERE haravan_variants.product_id = haravan_products.product_id
      AND inventory_locations.qty_available >= 0
) AS variant_data ON true

WHERE haravan_products.product_type NOT IN ('Round', 'Pear')
  AND variant_data.variants_json IS NOT NULL
  AND variant_data.variants_json::text <> '[]'
ORDER BY haravan_products.product_id
