{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

-- Salesaya temporary-product feed — GIA report numbers of temporary products that have been sold on
-- Haravan (matched to order lines by product and variant). Not deduplicated, mirroring the legacy
-- source view. Grain: 1 row per matched Haravan order line.
SELECT
    tp.gia_report_no AS gia_report_number
FROM {{ ref('int_catalog__temporary_products') }} tp
JOIN {{ ref('int_sales__sold_variants') }} sold
    ON sold.variant_id = tp.haravan_variant_id
   AND sold.product_id = tp.haravan_product_id
WHERE tp.gia_report_no IS NOT NULL
