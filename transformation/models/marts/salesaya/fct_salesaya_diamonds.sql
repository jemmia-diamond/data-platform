{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya diamond feed — per-diamond attributes enriched with per-warehouse availability, Haravan
-- collection membership, best available deal, GIA certificate enrichment (pdf url / encrypted
-- report no), a combo flag (diamond paired with a jewelry serial) and a lifecycle history JSON,
-- plus flags indicating whether the diamond has been sold.
-- Grain: 1 row per diamond.
WITH diamond_collections AS (
    SELECT
        entity_id AS diamond_id,
        json_agg(json_build_object(
            'id', collection_id,
            'name', collection_name,
            'is_excluded', is_excluded,
            'discount_type', discount_type,
            'discount_value', discount_value
        )) AS collections
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'diamond'
    GROUP BY entity_id
),

best_deal AS (
    SELECT
        entity_id AS diamond_id,
        discount_type,
        discount_value
    FROM {{ ref('int_catalog__collection_deals') }}
    WHERE entity_type = 'diamond' AND best_deal_rank = 1
),

combo_diamonds AS (
    -- Diamonds that are paired with a jewelry variant serial (in a combo).
    SELECT DISTINCT diamond_id
    FROM {{ ref('stg_nocodb__variant_serials_diamonds') }}
),

temp_sold AS (
    SELECT DISTINCT tp.gia_report_no
    FROM {{ ref('int_catalog__temporary_products') }} tp
    JOIN {{ ref('int_sales__sold_variants') }} sold
        ON sold.variant_id = tp.haravan_variant_id
       AND sold.product_id = tp.haravan_product_id
    WHERE tp.gia_report_no IS NOT NULL
)

SELECT
    d.diamond_id                                                  AS id,
    d.barcode,
    d.product_id,
    d.variant_id,
    d.edge_size_1,
    d.edge_size_2,
    d.color,
    d.clarity,
    d.fluorescence,
    d.shape,
    d.cut,
    d.carat,
    gia.pdf_url                                                  AS gia_pdf_url,
    gia.encrypted_report_no,
    d.is_incoming,
    d.base_price,
    CASE
        WHEN bd.discount_type = 'percent' THEN d.base_price * (1 - COALESCE(bd.discount_value, 0) / 100)
        WHEN bd.discount_type = 'amount'  THEN d.base_price - COALESCE(bd.discount_value, 0)
        ELSE d.base_price
    END                                                           AS sale_price,
    v.qty_available,
    v.qty_onhand,
    v.qty_commited,
    v.qty_incoming,
    bd.discount_type,
    bd.discount_value,
    d.report_no,
    d.image_urls,
    sv.warehouses,
    dc.collections,
    dh.history,
    (combo.diamond_id IS NOT NULL)                                AS is_in_combo,
    (sold.variant_id IS NOT NULL)                                 AS exist_in_line_items,
    (ts.gia_report_no IS NOT NULL)                                AS is_temp_product_and_exist_in_line_items

FROM {{ ref('int_catalog__diamonds') }} d
LEFT JOIN {{ ref('int_catalog__variants') }} v
    ON v.variant_id = d.variant_id
LEFT JOIN {{ ref('int_inventory__stock_by_variant') }} sv
    ON sv.variant_id = d.variant_id
LEFT JOIN {{ ref('stg_gia_edu__report_no_data') }} gia
    ON gia.report_no = d.report_no::text
LEFT JOIN diamond_collections dc
    ON dc.diamond_id = d.diamond_id
LEFT JOIN best_deal bd
    ON bd.diamond_id = d.diamond_id
LEFT JOIN {{ ref('int_catalog__diamond_history') }} dh
    ON dh.diamond_id = d.diamond_id
LEFT JOIN combo_diamonds combo
    ON combo.diamond_id = d.diamond_id
LEFT JOIN {{ ref('int_sales__sold_variants') }} sold
    ON sold.variant_id = d.variant_id
   AND sold.product_id = d.product_id
LEFT JOIN temp_sold ts
    ON ts.gia_report_no::text = d.report_no::text
