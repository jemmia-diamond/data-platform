{{ config(
    schema='marts_ecom'
) }}

-- Ecom diamonds catalog — thin SELECT from int_ecom__diamonds_base.
-- Replicates fn diamond LIST (buildGetDiamondsQuery) exactly:
--   is_gia_title AND in_stock_5 AND is_single_variant AND is_not_excluded
-- Detail BFF queries int_ecom__diamonds_base directly (only is_gia_title AND in_stock_5).
-- Plus: diamonds linked to a jewelry serial via variant_serials_diamonds (combo stones)
-- are excluded from the standalone catalog listing.

SELECT
    id,
    product_id,
    variant_id,
    report_no,
    shape,
    carat,
    color,
    clarity,
    cut,
    fluorescence,
    edge_size_1,
    edge_size_2,
    compare_at_price,
    price,
    final_discounted_price,
    title,
    handle,
    images,
    sku,
    collections,
    encrypted_report_no,
    gia_url,
    propimg

FROM {{ ref('int_ecom__diamonds_base') }} d
WHERE d.is_gia_title
  AND d.in_stock_5
  AND d.is_single_variant
  AND d.is_not_excluded
  -- NOT EXISTS (NULL-safe): exclude diamonds bound to a variant serial (jewelry+diamond combo)
  AND NOT EXISTS (
      SELECT 1
      FROM {{ ref('stg_nocodb__variant_serials_diamonds') }} vsd
      WHERE vsd.diamond_id = d.id
  )
