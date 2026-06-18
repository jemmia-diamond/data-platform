{{ config(
    materialized='materialized_view',
    schema='marts_metabot',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_metabot_commissions_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_metabot_commissions_sales_person_id ON {{ this }} (sales_person_id)",
    ]
) }}

-- Metabot commissions fact. Grain: 1 row = 1 order group × sales person.
-- Source: int_sales__sales_teams JOIN int_sales__orders (valid-order filter), GROUP BY (group, sales_person).
-- group_share_pct = SUM(allocated_amount) / NULLIF(group_net_total, 0) × 100.

WITH valid_orders AS (
    SELECT
        unified_sales_order_id,
        erp_sales_order_id,
        COALESCE(split_order_group, unified_sales_order_id) AS order_id,
        gross_amount,
        net_amount
    FROM {{ ref('int_sales__orders') }}
    WHERE {{ metabot_valid_orders_filter() }}
),

-- Per-order allocated gross/net from team percentage (each order is internally 100% allocated)
team_with_order AS (
    SELECT
        o.order_id,
        t.sales_person_id,
        t.erp_sales_order_id,
        t.allocated_amount,
        t.incentives_amount,
        t.allocated_percentage,
        o.gross_amount,
        o.net_amount
    FROM {{ ref('int_sales__sales_teams') }} t
    INNER JOIN valid_orders o
        ON t.erp_sales_order_id = o.erp_sales_order_id
),

group_net AS (
    SELECT
        order_id,
        SUM(net_amount) AS group_net_total
    FROM valid_orders
    GROUP BY 1
)

SELECT
    g.order_id || ':' || g.sales_person_id AS commission_id,
    g.order_id,
    g.sales_person_id,
    COUNT(DISTINCT g.erp_sales_order_id) AS source_order_count,
    SUM(g.allocated_amount) AS allocated_amount_vnd,
    SUM(g.incentives_amount) AS incentives_vnd,
    SUM(g.gross_amount * COALESCE(g.allocated_percentage, 100) / 100) AS allocated_gross_vnd,
    SUM(g.net_amount * COALESCE(g.allocated_percentage, 100) / 100) AS allocated_net_vnd,
    SUM(g.allocated_amount) / NULLIF(gn.group_net_total, 0) * 100 AS group_share_pct
FROM team_with_order g
LEFT JOIN group_net gn
    ON g.order_id = gn.order_id
GROUP BY
    g.order_id,
    g.sales_person_id,
    gn.group_net_total
