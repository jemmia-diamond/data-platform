{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH wedding_rings AS (
    SELECT * FROM {{ ref('stg_nocodb__wedding_rings') }}
),

designs AS (
    SELECT * FROM {{ ref('int_catalog__designs') }}
),

catalog_products AS (
    SELECT * FROM {{ ref('int_catalog__products') }}
),

wedding_ring_designs AS (
    SELECT
        wedding_rings.wedding_ring_id,
        designs.design_id,
        designs.design_code,
        designs.gender,
        designs.design_type
    FROM wedding_rings
    JOIN designs
        ON designs.wedding_ring_id = wedding_rings.wedding_ring_id
    JOIN catalog_products
        ON catalog_products.design_id = designs.design_id
),

valid_wedding_rings AS (
    SELECT wedding_ring_id
    FROM wedding_ring_designs
    WHERE gender IN ('Nam', 'Nữ')
      AND design_type = 'Nhẫn Cưới'
    GROUP BY wedding_ring_id
    HAVING COUNT(DISTINCT gender) = 2
)

SELECT
    wedding_ring_designs.wedding_ring_id,
    CONCAT('Nhẫn Cưới ', STRING_AGG(DISTINCT wedding_ring_designs.design_code, ' / ')) AS title
FROM wedding_ring_designs
JOIN valid_wedding_rings
    ON valid_wedding_rings.wedding_ring_id = wedding_ring_designs.wedding_ring_id
GROUP BY wedding_ring_designs.wedding_ring_id
