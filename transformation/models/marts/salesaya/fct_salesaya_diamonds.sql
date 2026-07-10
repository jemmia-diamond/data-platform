{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH diamonds AS (
    SELECT * FROM {{ ref('stg_nocodb__diamonds') }}
),

haravan_variants AS (
    SELECT * FROM {{ ref('stg_haravan__product_variants') }}
),

warehouse_json AS (
    SELECT
        inventory_locations.variant_id,
        json_agg(json_build_object(
            'id', locations.location_id,
            'name', locations.name,
            'qty_available', inventory_locations.qty_available
        )) AS warehouses
    FROM {{ ref('stg_haravan__inventory_locations') }} AS inventory_locations
    JOIN {{ ref('stg_haravan__locations') }} AS locations
        ON locations.location_id = inventory_locations.location_id
    WHERE inventory_locations.qty_available > 0
    GROUP BY inventory_locations.variant_id
),

collection_json AS (
    SELECT
        diamond_collection_links.diamond_id,
        json_agg(json_build_object(
            'id', haravan_collections.haravan_collection_id,
            'name', haravan_collections.title,
            'is_excluded', haravan_collections.is_excluded,
            'discount_type', haravan_collections.discount_type,
            'discount_value', haravan_collections.discount_value
        )) AS collections,
        MAX(haravan_collections.discount_value) AS max_discount
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }} AS diamond_collection_links
    JOIN {{ ref('stg_nocodb__haravan_collections') }} AS haravan_collections
        ON haravan_collections.haravan_collection_id = diamond_collection_links.haravan_collection_id
    GROUP BY diamond_collection_links.diamond_id
),

best_deal AS (
    SELECT DISTINCT ON (diamond_collection_links.diamond_id)
        diamond_collection_links.diamond_id,
        haravan_collections.discount_type,
        haravan_collections.discount_value
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }} AS diamond_collection_links
    JOIN {{ ref('stg_nocodb__haravan_collections') }} AS haravan_collections
        ON haravan_collections.haravan_collection_id = diamond_collection_links.haravan_collection_id
    ORDER BY diamond_collection_links.diamond_id, haravan_collections.discount_value DESC
),

line_item_exists AS (
    SELECT DISTINCT
        variant_id,
        product_id
    FROM {{ ref('stg_haravan__order_lines') }}
),

temp_product_exists AS (
    SELECT DISTINCT temporary_products.gia_report_no
    FROM {{ ref('stg_nocodb__temporary_products') }} AS temporary_products
    JOIN {{ ref('stg_haravan__order_lines') }} AS order_lines
        ON order_lines.variant_id = temporary_products.haravan_variant_id
       AND order_lines.product_id = temporary_products.haravan_product_id
)

-- gia_data is disabled until the `gia` schema is ingested.
-- Re-enable this CTE (and the join below) with the future staging model
-- for gia.report_no_data (e.g. stg_gia__report_no_data):
-- , gia_data AS (
--     SELECT DISTINCT ON (report_no)
--         report_no,
--         pdf_url,
--         encrypted_report_no
--     FROM gia.report_no_data
--     ORDER BY report_no
-- )

SELECT
    diamonds.diamond_id                                                  AS id,
    diamonds.barcode,
    diamonds.haravan_product_id                                          AS product_id,
    diamonds.haravan_variant_id                                          AS variant_id,
    diamonds.edge_size_1,
    diamonds.edge_size_2,
    diamonds.color,
    diamonds.clarity,
    diamonds.fluorescence,
    diamonds.shape,
    diamonds.cut,
    diamonds.carat,

    -- gia_pdf_url and encrypted_report_no are disabled until the `supplychain`
    -- and `gia` schemas are ingested (sources: supplychain.diamond_attribute, gia.report_no_data).
    -- COALESCE(diamond_attribute.pdf_url, gia_data.pdf_url::text)       AS gia_pdf_url,
    -- gia_data.encrypted_report_no,

    diamonds.is_incoming,
    diamonds.price                                                       AS base_price,
    CASE
        WHEN best_deal.discount_type = 'percent' THEN diamonds.price * (1 - COALESCE(best_deal.discount_value, 0) / 100)
        WHEN best_deal.discount_type = 'amount'  THEN diamonds.price - COALESCE(best_deal.discount_value, 0)
        ELSE diamonds.price
    END                                                                  AS sale_price,

    -- expected_arrival_date is unavailable: the NocoDB diamonds table has no such field.
    -- diamonds.expected_arrival_date,

    haravan_variants.qty_available,
    haravan_variants.qty_incoming,
    haravan_variants.qty_onhand,
    haravan_variants.qty_commited,
    best_deal.discount_type,
    best_deal.discount_value,
    diamonds.report_no,
    diamonds.image_urls,
    warehouse_json.warehouses,
    collection_json.collections,
    line_item_exists.variant_id IS NOT NULL                              AS exist_in_line_items,
    temp_product_exists.gia_report_no IS NOT NULL                        AS is_temp_product_and_exist_in_line_items

FROM diamonds
LEFT JOIN haravan_variants
    ON haravan_variants.variant_id = diamonds.haravan_variant_id

-- supplychain.diamond_attribute is disabled until the `supplychain` schema is ingested.
-- LEFT JOIN supplychain.diamond_attribute AS diamond_attribute
--     ON diamond_attribute.report_no = diamonds.report_no::text

-- gia_data is disabled until the `gia` schema is ingested.
-- LEFT JOIN gia_data
--     ON gia_data.report_no::text = diamonds.report_no::text

LEFT JOIN warehouse_json
    ON warehouse_json.variant_id = diamonds.haravan_variant_id
LEFT JOIN collection_json
    ON collection_json.diamond_id = diamonds.diamond_id
LEFT JOIN best_deal
    ON best_deal.diamond_id = diamonds.diamond_id
LEFT JOIN line_item_exists
    ON line_item_exists.variant_id = diamonds.haravan_variant_id
   AND line_item_exists.product_id = diamonds.haravan_product_id
LEFT JOIN temp_product_exists
    ON temp_product_exists.gia_report_no = diamonds.report_no::text
