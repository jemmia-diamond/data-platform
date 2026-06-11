{{ config(
    materialized='incremental',
    unique_key='order_id',
    schema='intermediate',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_ihoa_order_id ON {{ this }} (order_id)",
    ]
) }}

WITH RECURSIVE all_orders AS (
    SELECT
        order_id,
        ref_order_id,
        created_at
    FROM {{ ref('stg_haravan__orders') }}
),

new_orders AS (
    SELECT
        order_id,
        ref_order_id,
        created_at
    FROM all_orders
    {% if is_incremental() %}
    WHERE order_id NOT IN (SELECT order_id FROM {{ this }})
    {% endif %}
),

chain AS (
    SELECT
        order_id,
        ref_order_id,
        created_at,
        created_at AS root_date,
        ARRAY[order_id] AS path,
        1 AS depth
    FROM new_orders

    UNION ALL

    SELECT
        c.order_id,
        o.ref_order_id,
        o.created_at,
        LEAST(c.root_date, o.created_at) AS root_date,
        c.path || o.order_id AS path,
        c.depth + 1 AS depth
    FROM chain c
    JOIN all_orders o ON c.ref_order_id = o.order_id
    WHERE c.ref_order_id != 0
      AND NOT o.order_id = ANY(c.path)
      AND c.depth < 100
)

SELECT
    order_id,
    MIN(root_date) AS first_order_at
FROM chain
GROUP BY 1
