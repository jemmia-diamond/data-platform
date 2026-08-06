{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["id"]}, {"columns": ["variant_id"]}, {"columns": ["product_id"]}]
) }}

-- All published, in-stock loose diamonds with pricing, GIA metadata, collections, and eligibility flags.
-- Single source of truth for fct_ecom_diamonds_catalog (list/detail/gia-report) and
-- int_ecom__jewelry_diamond_matched (candidate selection).
--
-- HARD filters (applied via INNER JOIN — all consumers require these):
--   published_scope IN ('web', 'global')
--   qty_available > 0
--
-- SOFT flags (consumers filter as needed):
--   in_stock_5       — stock at 5 retail warehouses (catalog list requirement)
--   in_stock_3       — stock at 3 retail stores (diamond matching requirement)
--   is_single_variant — product has exactly 1 variant
--   is_not_excluded  — not in excluded collections [25,26,27,29]
--   is_gia_title     — variant title starts with 'GIA'

WITH diamond_stock AS (
    -- Single pass over int_inventory__stock_by_location (VIEW) — compute both 5-warehouse
    -- and 3-store stock flags in one scan instead of two.
    SELECT
        sl.variant_id,
        COALESCE(SUM(sl.qty_available) FILTER (WHERE sl.location_name IN (
            '[HCM] Cửa Hàng HCM', '[HN] Cửa Hàng HN', '[CT] Cửa Hàng Cần Thơ',
            '[HCM] Kế Toán', '[HCM] Admin')), 0) > 0 AS in_stock_5,
        COALESCE(SUM(sl.qty_available) FILTER (WHERE sl.location_name IN (
            '[HCM] Cửa Hàng HCM', '[HN] Cửa Hàng HN', '[CT] Cửa Hàng Cần Thơ')), 0) > 0 AS in_stock_3
    FROM {{ ref('int_inventory__stock_by_location') }} sl
    GROUP BY sl.variant_id
),

diamond_discount AS (
    SELECT m.diamond_id, MAX(hc.discount_value) AS max_discount
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }} m
    JOIN {{ ref('int_catalog__haravan_collections') }} hc
        ON hc.collection_id = m.haravan_collection_id
    WHERE hc.discount_type IS NOT NULL AND hc.discount_type <> ''
    GROUP BY m.diamond_id
),

diamond_collections AS (
    SELECT
        m.diamond_id,
        jsonb_agg(jsonb_build_object(
            'collection_id', m.haravan_collection_id,
            'title', hc.collection_name,
            'is_excluded', hc.is_excluded
        )) AS collections
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }} m
    JOIN {{ ref('int_catalog__haravan_collections') }} hc
        ON hc.collection_id = m.haravan_collection_id
    GROUP BY m.diamond_id
),

excluded AS (
    SELECT DISTINCT diamond_id
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
    WHERE haravan_collection_id IN {{ ecom_excluded_diamond_collections() }}
)

SELECT
    nd.diamond_id                                                       AS id,
    nd.product_id,
    nd.variant_id,
    nd.report_no,
    nd.shape,
    nd.carat,
    nd.color,
    nd.clarity,
    nd.cut,
    nd.fluorescence,
    nd.edge_size_1,
    nd.edge_size_2,
    nd.base_price                                                       AS compare_at_price,
    ROUND(
        CASE WHEN COALESCE(dd.max_discount, 0) > 0
             THEN nd.base_price * (100 - dd.max_discount) / 100
             ELSE nd.base_price
        END, 2
    )                                                                   AS price,
    COALESCE(
        nd.final_discounted_price,
        ROUND(
            CASE WHEN COALESCE(dd.max_discount, 0) > 0
                 THEN nd.base_price * (100 - dd.max_discount) / 100
                 ELSE nd.base_price
            END, 2
        )
    )                                                                   AS final_discounted_price,
    p.title,
    p.handle,
    COALESCE((SELECT array_agg(elem ->> 'src' ORDER BY (elem ->> 'position')::int NULLS LAST)
              FROM jsonb_array_elements(p.images::jsonb) elem), ARRAY[]::text[]) AS images,
    COALESCE(dc.collections, '[]'::jsonb)                               AS collections,
    nd.sku                                                              AS diamond_sku,
    nd.product_name                                                     AS diamond_product_name,
    v.variant_title,
    v.qty_available,
    gia.simple_encrypted_report_no                                      AS encrypted_report_no,
    CASE WHEN gia.simple_encrypted_report_no IS NOT NULL
         THEN '{{ var("ecom_website_public_url", "") }}/website/gia-reports/' || gia.simple_encrypted_report_no || '.png'
         ELSE NULL
    END                                                                 AS gia_url,
    gia.propimg,
    -- Stock flags (from single-pass diamond_stock CTE)
    COALESCE(ds.in_stock_5, false)                                      AS in_stock_5,
    COALESCE(ds.in_stock_3, false)                                      AS in_stock_3,
    -- Eligibility flags
    (COALESCE(p.variant_count, 1) = 1)                                  AS is_single_variant,
    (ex.diamond_id IS NULL)                                             AS is_not_excluded,
    (v.variant_title LIKE 'GIA%')                                       AS is_gia_title

FROM {{ ref('int_catalog__diamonds') }} nd
INNER JOIN {{ ref('int_catalog__products') }} p
    ON p.product_id = nd.product_id
   AND p.published_scope IN ('web', 'global')
INNER JOIN {{ ref('int_catalog__variants') }} v
    ON v.variant_id = nd.variant_id
   AND v.qty_available > 0
LEFT JOIN diamond_stock ds ON ds.variant_id = nd.variant_id
LEFT JOIN diamond_discount dd ON dd.diamond_id = nd.diamond_id
LEFT JOIN diamond_collections dc ON dc.diamond_id = nd.diamond_id
LEFT JOIN excluded ex ON ex.diamond_id = nd.diamond_id
LEFT JOIN {{ ref('stg_gia_edu__report_no_data') }} gia ON gia.report_no = nd.report_no::text
