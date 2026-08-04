{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["haravan_product_id", "haravan_variant_id"]}]
) }}

-- Ecom jewelry diamond matching — auto-pairs jewelry settings with candidate loose GIA diamonds.
-- Candidates sourced from int_ecom__diamonds_base (single source of truth).
-- Matching: edge_size_2 ∈ [target_mm, target_mm + 0.1) where target_mm parsed from main_stone.
-- Grain: 1 row per (haravan_product_id, haravan_variant_id) that has an eligible candidate diamond.

WITH jewelry_variants AS (
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

candidate_diamonds AS (
    SELECT
        id              AS diamond_id,
        product_id      AS diamond_product_id,
        variant_id      AS diamond_variant_id,
        report_no::text AS report_no,
        shape,
        carat,
        color,
        clarity,
        cut,
        edge_size_1,
        edge_size_2,
        compare_at_price,
        price
    FROM {{ ref('int_ecom__diamonds_base') }}
    WHERE (is_gia_title OR diamond_sku LIKE '%-GIA%' OR diamond_product_name LIKE 'GIA%')
      AND in_stock_3
      AND is_single_variant
      AND is_not_excluded
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
