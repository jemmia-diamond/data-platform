{{ config(
    schema='marts_ecom'
) }}

-- Public ecom jewelry-products feed. Full product-fact logic lives in
-- int_ecom__jewelry_products (all product types, reused by fct_ecom_wedding_rings for member
-- prices/qty). This feed EXCLUDES 'Nhẫn Cưới': wedding rings are served only through the
-- pair-gated wedding-ring mart/endpoints (fct_ecom_wedding_rings), so they can no longer appear
-- in jewelry search/list/detail without a formed pair-detail.

SELECT *
FROM {{ ref('int_ecom__jewelry_products') }}
WHERE haravan_product_type <> 'Nhẫn Cưới'
