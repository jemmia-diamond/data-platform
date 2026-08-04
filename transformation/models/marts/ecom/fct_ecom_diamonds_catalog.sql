{{ config(
    schema='marts_ecom'
) }}

-- Ecom diamonds catalog — thin SELECT from int_ecom__diamonds_base.
-- List filter: is_gia_title AND in_stock_5.
-- Detail BFF: does NOT filter on is_listed (matches fn detail behavior).

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
    collections,
    encrypted_report_no,
    gia_url,
    propimg,
    is_single_variant,
    is_not_excluded,
    (is_single_variant AND is_not_excluded)                                          AS is_listed

FROM {{ ref('int_ecom__diamonds_base') }}
WHERE is_gia_title
  AND in_stock_5
