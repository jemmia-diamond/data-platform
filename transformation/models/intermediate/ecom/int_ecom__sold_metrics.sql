{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Ecom sold metrics — total sold quantity per Haravan product, mirroring the legacy worker
-- buildInventoryMetricsSql. Earring types ('Bông Tai', 'Bông Tai Nguyên Chiếc') are sold by the
-- pair so their line-item quantity is halved. Only uncancelled orders count. Adds the pre-2025
-- baseline carried in NocoDB products (sold_before_2025).
-- Grain: 1 row per Haravan product.
WITH sold_post_2025 AS (
    SELECT
        ln.product_id,
        SUM(
            CASE
                WHEN p.product_type IN ('Bông Tai', 'Bông Tai Nguyên Chiếc')
                    THEN ln.quantity::numeric / 2.0
                ELSE ln.quantity::numeric
            END
        ) AS sold_post_2025
    FROM {{ ref('stg_haravan__order_lines') }} ln
    INNER JOIN {{ ref('stg_haravan__orders') }} o
        ON o.order_id = ln.order_id
    LEFT JOIN {{ ref('stg_haravan__products') }} p
        ON p.product_id = ln.product_id
    WHERE o.cancelled_status = 'uncancelled'
      AND ln.product_id IS NOT NULL
      AND ln.quantity IS NOT NULL
    GROUP BY ln.product_id
)

SELECT
    p.product_id,
    COALESCE(s.sold_post_2025, 0)                                AS sold_post_2025,
    COALESCE(np.sold_before_2025, 0)                             AS sold_before_2025,
    (COALESCE(s.sold_post_2025, 0) + COALESCE(np.sold_before_2025, 0))::int AS sold_quantity
FROM {{ ref('stg_haravan__products') }} p
LEFT JOIN sold_post_2025 s
    ON s.product_id = p.product_id
LEFT JOIN {{ ref('stg_nocodb__products') }} np
    ON np.haravan_product_id = p.product_id
