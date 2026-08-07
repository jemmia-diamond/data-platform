{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["haravan_product_id", "haravan_variant_id"]}]
) }}

-- Ecom jewelry diamond matching — auto-pairs jewelry settings with a candidate loose GIA diamond.
-- Re-implements fn ecom.jewelry_diamond_pairs logic (deterministic, stateless):
--   - Candidate diamonds (fn findReplacementDiamond eligibility):
--       is_gia_title AND in_stock_3 AND is_single_variant AND is_not_excluded
--       edge_size_2 ∈ [4.5, 4.6)   (fn uses this FIXED range for every jewelry)
--   - Jewelry eligibility: product_type <> 'Nhẫn Cưới', design_id not null,
--       not a serial-diamond variant (excludeSerialsDiamonds)
--   - Assignment: fn picks RANDOM among candidates preferring globally-unpaired diamonds and
--     PERSISTS the choice. That state is non-reproducible, so we assign DETERMINISTICALLY with an
--     even spread (round-robin by variant_id rank): each candidate diamond is reused only after all
--     others have been assigned, minimizing repeated diamonds across jewelry.
-- Grain: 1 row per (haravan_product_id, haravan_variant_id) that has an eligible candidate diamond.

WITH jewelry AS (
    SELECT
        v.product_id   AS haravan_product_id,
        v.variant_id   AS haravan_variant_id,
        ROW_NUMBER() OVER (ORDER BY v.variant_id) AS jrn
    FROM {{ ref('int_catalog__variants') }} v
    INNER JOIN {{ ref('int_catalog__products') }} p
        ON p.product_id = v.product_id
    WHERE p.product_type <> 'Nhẫn Cưới'
      AND p.design_id IS NOT NULL
      AND v.variant_id NOT IN (SELECT haravan_variant_id FROM {{ ref('int_ecom__serial_diamond_variants') }})
),

candidate_diamonds AS (
    SELECT
        db.id              AS diamond_id,
        db.product_id      AS diamond_product_id,
        db.variant_id      AS diamond_variant_id,
        db.report_no::text AS report_no,
        db.shape,
        db.carat,
        db.color,
        db.clarity,
        db.cut,
        db.edge_size_1,
        db.edge_size_2,
        db.compare_at_price,
        db.price,
        ROW_NUMBER() OVER (ORDER BY db.variant_id) AS crn,
        COUNT(*) OVER ()                           AS total_cands
    FROM {{ ref('int_ecom__diamonds_base') }} db
    WHERE (db.is_gia_title OR db.diamond_sku LIKE '%-GIA%' OR db.diamond_product_name LIKE 'GIA%')
      AND db.in_stock_3
      AND db.is_single_variant
      AND db.is_not_excluded
      AND db.edge_size_2 >= 4.5
      AND db.edge_size_2 < 4.6
),

-- Round-robin: jewelry rank jrn → candidate rank ((jrn-1) % total)+1. Spreads diamonds evenly.
pairs AS (
    SELECT
        j.haravan_product_id,
        j.haravan_variant_id,
        c.diamond_product_id,
        c.diamond_variant_id,
        c.report_no,
        c.shape,
        c.carat,
        c.color,
        c.clarity,
        c.cut,
        c.edge_size_1,
        c.edge_size_2,
        c.compare_at_price,
        c.price
    FROM jewelry j
    JOIN candidate_diamonds c
        ON ((j.jrn - 1) % c.total_cands) + 1 = c.crn
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
FROM pairs
