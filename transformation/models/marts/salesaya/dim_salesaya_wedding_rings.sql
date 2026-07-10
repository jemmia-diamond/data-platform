{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH wedding_rings AS (
    SELECT * FROM {{ ref('stg_nocodb__wedding_rings') }}
),

designs AS (
    SELECT * FROM {{ ref('stg_nocodb__designs') }}
),

nocodb_products AS (
    SELECT * FROM {{ ref('stg_nocodb__products') }}
),

haravan_products AS (
    SELECT * FROM {{ ref('stg_haravan__products') }}
),

valid_wedding_rings AS (
    SELECT wedding_rings.wedding_ring_id
    FROM wedding_rings
    JOIN designs
        ON designs.wedding_ring_id = wedding_rings.wedding_ring_id
    JOIN nocodb_products
        ON nocodb_products.design_id = designs.design_id
    JOIN haravan_products
        ON haravan_products.product_id = nocodb_products.haravan_product_id
    WHERE designs.gender IN ('Nam', 'Nữ')
      AND designs.design_type = 'Nhẫn Cưới'
    GROUP BY wedding_rings.wedding_ring_id
    HAVING COUNT(DISTINCT designs.gender) = 2
)

SELECT
    wedding_rings.wedding_ring_id                                        AS id,
    CONCAT('Nhẫn Cưới ', STRING_AGG(DISTINCT designs.design_code, ' / ')) AS title
FROM wedding_rings
JOIN designs
    ON designs.wedding_ring_id = wedding_rings.wedding_ring_id
JOIN nocodb_products
    ON nocodb_products.design_id = designs.design_id
JOIN haravan_products
    ON haravan_products.product_id = nocodb_products.haravan_product_id
WHERE wedding_rings.wedding_ring_id IN (
    SELECT wedding_ring_id FROM valid_wedding_rings
)
GROUP BY wedding_rings.wedding_ring_id
