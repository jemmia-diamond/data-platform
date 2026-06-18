{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot order purposes bridge. Grain: 1 row = 1 order group × 1 purchase purpose.
-- Source: int_sales__order_purchase_purposes JOIN int_sales__orders (valid-order filter via macro).
-- Allocation is EVEN SPLIT across purposes within a group (purpose_count_per_order).
-- Caveat: purposes are ERPNext manual tags, not derived from line items. Even-split is approximate.
-- Uses same group_key COALESCE as fct_metabot_orders for FK consistency.

WITH valid_orders AS (
    SELECT
        unified_sales_order_id,
        COALESCE(split_order_group, unified_sales_order_id) AS order_id,
        erp_sales_order_id,
        gross_amount,
        net_amount,
        total_qty
    FROM {{ ref('int_sales__orders') }}
    WHERE {{ metabot_valid_orders_filter() }}
),

group_purposes AS (
    SELECT DISTINCT
        o.order_id,
        p.purpose_name
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_purchase_purposes') }} p
        ON o.erp_sales_order_id = p.erp_sales_order_id
    WHERE p.purpose_name IS NOT NULL
),

group_totals AS (
    SELECT
        o.order_id,
        SUM(o.gross_amount) AS group_gross,
        SUM(o.net_amount) AS group_net,
        SUM(o.total_qty) AS group_qty,
        COUNT(DISTINCT p.purpose_name) AS purpose_count
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_purchase_purposes') }} p
        ON o.erp_sales_order_id = p.erp_sales_order_id
    WHERE p.purpose_name IS NOT NULL
    GROUP BY o.order_id
)

SELECT
    gp.order_id || ':' || gp.purpose_name AS purpose_link_id,
    gp.order_id,
    gp.purpose_name,
    gt.purpose_count AS purpose_count_per_order,
    gt.group_gross / gt.purpose_count AS allocated_gross_vnd,
    gt.group_net / gt.purpose_count AS allocated_net_vnd,
    gt.group_qty / gt.purpose_count AS allocated_quantity
FROM group_purposes gp
JOIN group_totals gt ON gp.order_id = gt.order_id
