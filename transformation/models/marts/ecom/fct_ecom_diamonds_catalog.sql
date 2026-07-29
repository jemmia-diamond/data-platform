{{ config(
    schema='marts_ecom'
) }}

-- Ecom diamonds catalog — replaces the legacy worker raw diamond query (list/detail/gia-report
-- APIs). One row per loose diamond that is published (web/global), single-variant, in stock at
-- one of the 5 retail warehouses, with a GIA-prefixed variant and not in an excluded collection.
-- Carries physical attributes, list price + collection-discount price, Haravan product imagery
-- and the GIA report metadata (encrypted report no, propimg, gia_url).
WITH retail_warehouses(name) AS (
    VALUES
        ('[HCM] Cửa Hàng HCM'),
        ('[HN] Cửa Hàng HN'),
        ('[CT] Cửa Hàng Cần Thơ'),
        ('[HCM] Kế Toán'),
        ('[HCM] Admin')
),

in_stock_variants AS (
    SELECT sl.variant_id
    FROM {{ ref('int_inventory__stock_by_location') }} sl
    JOIN retail_warehouses rw ON rw.name = sl.location_name
    GROUP BY sl.variant_id
    HAVING SUM(sl.qty_available) > 0
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

excluded AS (
    SELECT DISTINCT diamond_id
    FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
    WHERE haravan_collection_id IN (25, 26, 27, 29)
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
)

SELECT
    nd.diamond_id                                                      AS id,
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
    nd.base_price                                                      AS compare_at_price,
    ROUND(
        CASE
            WHEN COALESCE(dd.max_discount, 0) > 0
                THEN nd.base_price * (100 - dd.max_discount) / 100
            ELSE nd.base_price
        END,
        2
    )                                                                  AS price,
    COALESCE(
        nd.final_discounted_price,
        ROUND(
            CASE
                WHEN COALESCE(dd.max_discount, 0) > 0
                    THEN nd.base_price * (100 - dd.max_discount) / 100
                ELSE nd.base_price
            END,
            2
        )
    )                                                                  AS final_discounted_price,
    p.title,
    p.handle,
    COALESCE((SELECT array_agg(elem ->> 'src' ORDER BY (elem ->> 'position')::int NULLS LAST)
              FROM jsonb_array_elements(p.images::jsonb) elem), ARRAY[]::text[]) AS images,
    COALESCE(dc.collections, '[]'::jsonb)                              AS collections,
    gia.simple_encrypted_report_no                                     AS encrypted_report_no,
    CASE
        WHEN gia.simple_encrypted_report_no IS NOT NULL
            THEN '{{ var("ecom_website_public_url", "") }}/website/gia-reports/' || gia.simple_encrypted_report_no || '.png'
        ELSE NULL
    END                                                                AS gia_url,
    gia.propimg

FROM {{ ref('int_catalog__diamonds') }} nd
INNER JOIN {{ ref('int_catalog__products') }} p
    ON p.product_id = nd.product_id
   AND p.published_scope IN ('web', 'global')
INNER JOIN {{ ref('int_catalog__variants') }} v
    ON v.variant_id = nd.variant_id
   AND v.qty_available > 0
   AND v.variant_title LIKE 'GIA%'
INNER JOIN in_stock_variants isv
    ON isv.variant_id = nd.variant_id
LEFT JOIN diamond_discount dd
    ON dd.diamond_id = nd.diamond_id
LEFT JOIN diamond_collections dc
    ON dc.diamond_id = nd.diamond_id
LEFT JOIN {{ ref('stg_gia_edu__report_no_data') }} gia
    ON gia.report_no = nd.report_no::text

WHERE nd.diamond_id NOT IN (SELECT diamond_id FROM excluded)
  AND COALESCE(p.variant_count, 1) = 1
