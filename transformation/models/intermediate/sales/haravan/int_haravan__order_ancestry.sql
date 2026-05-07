{{ config(
    materialized='view',
    schema='intermediate'
) }}

-- Recursive CTE to trace every Haravan order back to its root ancestor.
-- For each order, computes the earliest date in its chain (first_order_at).
-- Orders with ref_order_id = 0 are root orders (no parent).

WITH RECURSIVE orders AS (
    SELECT
        order_id,
        ref_order_id,
        created_at
    FROM {{ ref('stg_haravan__orders') }}
),

-- Walk up the ancestry chain: each iteration follows ref_order_id → parent
chain AS (
    SELECT
        order_id,
        ref_order_id,
        created_at,
        created_at AS root_date
    FROM orders

    UNION ALL

    SELECT
        c.order_id,
        o.ref_order_id,
        o.created_at,
        LEAST(c.root_date, o.created_at) AS root_date
    FROM chain c
    JOIN orders o ON c.ref_order_id = o.order_id
    WHERE c.ref_order_id != 0
)

SELECT
    order_id,
    MIN(root_date) AS first_order_at
FROM chain
GROUP BY 1
