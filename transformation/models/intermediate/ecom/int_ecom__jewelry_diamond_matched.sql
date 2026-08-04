{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["haravan_product_id", "haravan_variant_id"]}]
) }}

-- Ecom jewelry diamond matching — auto-pairs jewelry settings with candidate loose GIA diamonds.
-- Grain: 1 row per (haravan_product_id, haravan_variant_id) that has an eligible candidate diamond.

WITH retail_stores(name) AS (
    VALUES
        ('[HCM] Cửa Hàng HCM'),
        ('[HN] Cửa Hàng HN'),
        ('[CT] Cửa Hàng Cần Thơ')
),

in_stock_diamonds AS (
    SELECT sl.variant_id
    FROM {{ ref('int_inventory__stock_by_location') }} sl
    JOIN retail_stores rs ON rs.name = sl.location_name
    GROUP BY sl.variant_id
    HAVING SUM(sl.qty_available) > 0
),

jewelry_variants AS (
    SELECT
        v.product_id AS haravan_product_id,
        v.variant_id AS haravan_variant_id,
        CASE
            WHEN d.main_stone ~* '[0-9]+[lL][0-9]+' THEN
                CAST(REPLACE(LOWER(SUBSTRING(d.main_stone FROM '(?i)[0-9]+[lL][0-9]+')), 'l', '.') AS numeric)
            WHEN d.main_stone ~* '[0-9]+[lL]' THEN
                CAST(REPLACE(LOWER(SUBSTRING(d.main_stone FROM '(?i)[0-9]+[lL]')), 'l', '.0') AS numeric)
            WHEN d.main_stone ~* '[0-9]+\.[0-9]+' THEN
                CAST(SUBSTRING(d.main_stone FROM '[0-9]+\.[0-9]+') AS numeric)
            ELSE 4.5
        END AS target_mm
    FROM {{ ref('int_catalog__variants') }} v
    INNER JOIN {{ ref('int_catalog__products') }} p
        ON p.product_id = v.product_id
    INNER JOIN {{ ref('int_catalog__designs') }} d
        ON d.design_id = p.design_id
    WHERE p.product_type <> 'Nhẫn Cưới'
      AND p.design_id IS NOT NULL
      AND v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
),

excluded_collections AS (
    SELECT DISTINCT diamond_id
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
    WHERE haravan_collection_id IN (25, 26, 27, 29)
),

diamond_discount AS (
    SELECT
        m.diamond_id,
        MAX(hc.discount_value) AS max_discount
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }} m
    JOIN {{ ref('int_catalog__haravan_collections') }} hc
        ON hc.collection_id = m.haravan_collection_id
    WHERE hc.discount_type IS NOT NULL
      AND hc.discount_type <> ''
    GROUP BY m.diamond_id
),

candidate_diamonds AS (
    SELECT
        d.diamond_id,
        d.product_id AS diamond_product_id,
        d.variant_id AS diamond_variant_id,
        d.report_no::text AS report_no,
        d.shape,
        d.carat,
        d.color,
        d.clarity,
        d.cut,
        d.edge_size_1,
        d.edge_size_2,
        d.base_price AS compare_at_price,
        COALESCE(
            d.final_discounted_price,
            ROUND(
                CASE
                    WHEN COALESCE(dd.max_discount, 0) > 0
                        THEN d.base_price * (100 - dd.max_discount) / 100
                    ELSE d.base_price
                END,
                2
            )
        ) AS price
    FROM {{ ref('int_catalog__diamonds') }} d
    INNER JOIN {{ ref('int_catalog__products') }} p_dia
        ON p_dia.product_id = d.product_id
       AND p_dia.published_scope IN ('web', 'global')
       AND COALESCE(p_dia.variant_count, 1) = 1
    INNER JOIN {{ ref('int_catalog__variants') }} v
        ON v.variant_id = d.variant_id
       AND v.qty_available > 0
       AND (v.variant_title LIKE 'GIA%' OR d.sku LIKE '%-GIA%' OR d.product_name LIKE 'GIA%')
    INNER JOIN in_stock_diamonds isd
        ON isd.variant_id = d.variant_id
    LEFT JOIN diamond_discount dd
        ON dd.diamond_id = d.diamond_id
    WHERE d.diamond_id NOT IN (SELECT diamond_id FROM excluded_collections)
),

ranked_pairs AS (
    SELECT
        j.haravan_product_id,
        j.haravan_variant_id,
        cd.diamond_product_id,
        cd.diamond_variant_id,
        cd.report_no,
        cd.shape,
        cd.carat,
        cd.color,
        cd.clarity,
        cd.cut,
        cd.edge_size_1,
        cd.edge_size_2,
        cd.compare_at_price,
        cd.price,
        ROW_NUMBER() OVER (
            PARTITION BY j.haravan_product_id, j.haravan_variant_id
            ORDER BY cd.diamond_variant_id DESC
        ) AS rank_idx
    FROM jewelry_variants j
    INNER JOIN candidate_diamonds cd
        ON cd.edge_size_2 >= j.target_mm
       AND cd.edge_size_2 < (j.target_mm + 0.1)
)

SELECT
    haravan_product_id,
    haravan_variant_id,
    diamond_product_id,
    diamond_variant_id,
    report_no,
    shape,
    carat,
    color,
    clarity,
    cut,
    edge_size_1,
    edge_size_2,
    compare_at_price,
    price,
    jsonb_build_object(
        'product_id', diamond_product_id,
        'variant_id', diamond_variant_id,
        'report_no', report_no,
        'shape', shape,
        'carat', carat,
        'color', color,
        'clarity', clarity,
        'cut', cut,
        'edge_size_1', edge_size_1,
        'edge_size_2', edge_size_2,
        'compare_at_price', compare_at_price,
        'price', price
    ) AS diamond_json
FROM ranked_pairs
WHERE rank_idx = 1
