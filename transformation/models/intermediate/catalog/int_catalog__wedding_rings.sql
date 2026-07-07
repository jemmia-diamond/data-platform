{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH wedding_rings AS (
    SELECT * FROM {{ ref('stg_nocodb__wedding_rings') }}
),

designs AS (
    SELECT * FROM {{ ref('stg_nocodb__designs') }}
),

products AS (
    SELECT * FROM {{ ref('stg_nocodb__products') }}
),

haravan_products AS (
    SELECT * FROM {{ ref('stg_haravan__products') }}
),

paired_ring_designs AS (
    SELECT
        wr.wedding_ring_id,
        d.gender,
        d.design_code
    FROM wedding_rings wr
    JOIN designs d
        ON wr.wedding_ring_id = d.wedding_ring_id
    JOIN products p
        ON d.design_id = p.design_id
    JOIN haravan_products hp
        ON p.haravan_product_id = hp.product_id
    WHERE d.design_type = 'Nhẫn Cưới'
      AND d.gender IN ('Nam', 'Nữ')
)

SELECT
    wedding_ring_id,
    concat('Nhẫn Cưới ', string_agg(DISTINCT design_code, ' / ')) AS title
FROM paired_ring_designs
GROUP BY wedding_ring_id
HAVING count(DISTINCT gender) = 2
