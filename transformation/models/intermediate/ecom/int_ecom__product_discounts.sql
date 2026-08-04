{{ config(
    materialized='table',
    schema='intermediate',
    indexes=[{"columns": ["haravan_product_id"]}]
) }}

-- Max collection discount per Haravan product.
-- Single source of truth for both int_ecom__jewelry_variant_prices and fct_ecom_jewelry_products.
-- Matches MView materialized_variants/materialized_products discount_info subquery.

SELECT
    np.haravan_product_id,
    MAX(cd.discount_value)                                           AS max_discount
FROM {{ ref('int_catalog__collection_deals') }} cd
INNER JOIN {{ ref('stg_nocodb__products') }} np
    ON np.product_id = cd.entity_id
WHERE cd.entity_type = 'product'
  AND cd.discount_type IS NOT NULL
  AND cd.discount_type <> ''
  AND np.haravan_product_id IS NOT NULL
GROUP BY np.haravan_product_id
