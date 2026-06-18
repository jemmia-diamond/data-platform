{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot order product categories bridge. Grain: 1 row = 1 order group × 1 product category.
-- Source: int_sales__order_product_categories JOIN int_sales__orders (valid-order filter via macro).
-- Allocation is EVEN SPLIT across categories within a group (category_count_per_order).
-- Caveat: categories are ERPNext manual tags, not derived from line items. Even-split is approximate.
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

group_cats AS (
    SELECT DISTINCT
        o.order_id,
        c.category_name
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_product_categories') }} c
        ON o.erp_sales_order_id = c.erp_sales_order_id
    WHERE c.category_name IS NOT NULL
),

group_totals AS (
    SELECT
        o.order_id,
        SUM(o.gross_amount) AS group_gross,
        SUM(o.net_amount) AS group_net,
        SUM(o.total_qty) AS group_qty,
        COUNT(DISTINCT c.category_name) AS category_count
    FROM valid_orders o
    JOIN {{ ref('int_sales__order_product_categories') }} c
        ON o.erp_sales_order_id = c.erp_sales_order_id
    WHERE c.category_name IS NOT NULL
    GROUP BY o.order_id
)

SELECT
    gc.order_id || ':' || gc.category_name AS category_link_id,
    gc.order_id,
    gc.category_name,
    gt.category_count AS category_count_per_order,
    gt.group_gross / gt.category_count AS allocated_gross_vnd,
    gt.group_net / gt.category_count AS allocated_net_vnd,
    gt.group_qty / gt.category_count AS allocated_quantity
FROM group_cats gc
JOIN group_totals gt ON gc.order_id = gt.order_id
