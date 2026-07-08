{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH inventory_agg AS (
    SELECT
        inventory_locations.variant_id,
        jsonb_object_agg(locations.name, inventory_locations.qty_available)
            FILTER (WHERE inventory_locations.qty_available > 0)             AS stock_locations,
        SUM(inventory_locations.qty_available)                              AS total_qty,
        MAX(inventory_locations.location_id)                                AS primary_loc_id
    FROM {{ ref('stg_haravan__inventory_locations') }} AS inventory_locations
    JOIN {{ ref('stg_haravan__locations') }} AS locations
        ON locations.location_id = inventory_locations.location_id
    GROUP BY inventory_locations.variant_id
),

variant_calc AS (
    SELECT DISTINCT ON (haravan_variants.variant_id)
        haravan_variants.variant_id,
        haravan_variants.product_id,
        haravan_variants.variant_title                                      AS title,
        haravan_variants.price                                              AS base_price,
        CASE
            WHEN haravan_collections.start_date::timestamp <= now() AND haravan_collections.end_date::timestamp >= now()
                THEN nocodb_variants.final_discount_price
            WHEN haravan_collections.discount_type = 'percent'
                THEN haravan_variants.price * COALESCE(1 - haravan_collections.discount_value / 100, 1)
            WHEN haravan_collections.discount_type = 'amount'
                THEN haravan_variants.price - COALESCE(haravan_collections.discount_value, 0)
            ELSE haravan_variants.price
        END                                                                 AS sale_price,
        nocodb_variants.ring_size,
        -- storage_size_1 / storage_size_2 are not present in raw variant_serials.
        -- variant_serials.storage_size_1,
        -- variant_serials.storage_size_2,
        nocodb_variants.fineness,
        nocodb_variants.material_color,
        variant_serials.serial_number,
        haravan_collections.discount_type,
        haravan_collections.discount_value,
        haravan_collections.haravan_collection_id                           AS collection_id,
        primary_location.name                                               AS primary_stock_at
    FROM {{ ref('stg_haravan__product_variants') }} AS haravan_variants
    LEFT JOIN inventory_agg
        ON inventory_agg.variant_id = haravan_variants.variant_id
    LEFT JOIN {{ ref('stg_haravan__locations') }} AS primary_location
        ON primary_location.location_id = inventory_agg.primary_loc_id
    LEFT JOIN {{ ref('stg_nocodb__variants') }} AS nocodb_variants
        ON nocodb_variants.haravan_variant_id = haravan_variants.variant_id
    LEFT JOIN {{ ref('stg_nocodb__variant_serials') }} AS variant_serials
        ON variant_serials.variant_id = nocodb_variants.variant_id
    LEFT JOIN {{ ref('stg_nocodb__products') }} AS nocodb_products
        ON nocodb_products.product_id = nocodb_variants.product_id
    LEFT JOIN {{ ref('stg_nocodb__products_haravan_collection') }} AS product_collection_links
        ON product_collection_links.product_id = nocodb_products.product_id
    LEFT JOIN {{ ref('stg_nocodb__haravan_collections') }} AS haravan_collections
        ON haravan_collections.haravan_collection_id = product_collection_links.haravan_collection_id
    ORDER BY
        haravan_variants.variant_id,
        CASE
            WHEN haravan_collections.start_date::timestamp <= now() AND haravan_collections.end_date::timestamp >= now() THEN 1
            WHEN haravan_collections.start_date IS NULL THEN 2
            ELSE 3
        END,
        haravan_collections.discount_value DESC NULLS LAST,
        variant_serials.serial_id DESC
),

product_variants_agg AS (
    SELECT
        variant_calc.product_id,
        MIN(variant_calc.sale_price)                                        AS min_sale_price,
        SUM(COALESCE(inventory_agg.total_qty, 0))                           AS total_product_qty,
        jsonb_agg(jsonb_build_object(
            'id', variant_calc.variant_id::text,
            'title', variant_calc.title,
            'basePrice', variant_calc.base_price,
            'salePrice', variant_calc.sale_price,
            'stockAt', variant_calc.primary_stock_at,
            'ringSize', variant_calc.ring_size,
            -- 'storageSize1', variant_calc.storage_size_1,
            -- 'storageSize2', variant_calc.storage_size_2,
            'fineness', variant_calc.fineness,
            'quantityAvailable', COALESCE(inventory_agg.total_qty, 0),
            'materialColor', variant_calc.material_color,
            'serialNumber', variant_calc.serial_number,
            'discountType', variant_calc.discount_type,
            'discountValue', variant_calc.discount_value
        )) AS variants_json,
        array_agg(variant_calc.ring_size) FILTER (WHERE variant_calc.ring_size IS NOT NULL) AS all_ring_sizes
        -- all_storage_size_1 / all_storage_size_2 disabled: storage_size_1/2 not present in raw variant_serials.
        -- , array_agg(variant_calc.storage_size_1) FILTER (WHERE variant_calc.storage_size_1 IS NOT NULL) AS all_storage_size_1
        -- , array_agg(variant_calc.storage_size_2) FILTER (WHERE variant_calc.storage_size_2 IS NOT NULL) AS all_storage_size_2
    FROM variant_calc
    LEFT JOIN inventory_agg
        ON inventory_agg.variant_id = variant_calc.variant_id
    WHERE COALESCE(variant_calc.sale_price, variant_calc.base_price) > 0
    GROUP BY variant_calc.product_id
)

SELECT
    haravan_products.product_id                                             AS id,
    haravan_products.title,
    haravan_products.product_type,
    (
        SELECT jsonb_agg(jsonb_build_object(
            'id', retouch_file ->> 'id',
            'url', retouch_file ->> 'url',
            'size', retouch_file -> 'size',
            'title', retouch_file ->> 'title',
            'width', retouch_file -> 'width',
            'height', retouch_file -> 'height',
            'mimetype', retouch_file ->> 'mimetype'
        ))
        FROM jsonb_array_elements(design_data.retouch::jsonb) AS retouch_file
    )                                                                       AS retouch,
    design_data.code,
    design_data.erp_code,
    design_data.backup_code,
    design_data.design_code,
    design_data.diamond_holder,
    -- design_data."4view" is not ingested (not in the NocoDB designs field list).
    -- design_data."4view",
    haravan_products.images                                                 AS p_images,
    -- w_images / w_videos / render_images are not ingested
    -- (design_design_images only exposes id, design_id, material_color, retouch, ...).
    -- design_data.images AS w_images,
    -- design_data.videos AS w_videos,
    -- design_data.render_images,
    COALESCE(product_variants_agg.variants_json, '[]'::jsonb)               AS variants,
    product_variants_agg.min_sale_price,
    product_variants_agg.total_product_qty,
    product_variants_agg.all_ring_sizes
    -- all_storage_size_1 / all_storage_size_2 disabled: storage_size_1/2 not present in raw variant_serials.
    -- , product_variants_agg.all_storage_size_1
    -- , product_variants_agg.all_storage_size_2

FROM {{ ref('stg_haravan__products') }} AS haravan_products
JOIN product_variants_agg
    ON product_variants_agg.product_id = haravan_products.product_id
LEFT JOIN LATERAL (
    SELECT
        design_images.retouch,
        -- design_images.images,
        -- design_images.videos,
        -- design_images.render_images,
        -- designs."4view",
        designs.design_code_legacy                                          AS code,
        designs.erp_code,
        designs.backup_code,
        designs.design_code,
        designs.diamond_holder
    FROM {{ ref('stg_nocodb__products') }} AS nocodb_products
    JOIN {{ ref('stg_nocodb__design_design_images') }} AS design_images
        ON design_images.design_id = nocodb_products.design_id
    JOIN {{ ref('stg_nocodb__designs') }} AS designs
        ON designs.design_id = nocodb_products.design_id
    WHERE nocodb_products.haravan_product_id = haravan_products.product_id
      AND design_images.retouch IS NOT NULL
      AND design_images.retouch <> '[]'
    LIMIT 1
) AS design_data ON true

WHERE design_data.retouch IS NOT NULL
  AND design_data.retouch <> '[]'
