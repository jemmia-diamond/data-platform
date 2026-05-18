{{ config(
    materialized='view',
    schema='intermediate',
    meta={'depends_on': ['int_haravan__order_ancestry']}
) }}

-- For each ERPNext sales order, compute the earliest "real" order date
-- across its entire split order group.
--
-- Logic:
--   1. Look up the Haravan ancestry date (if the order originated from Haravan)
--   2. Take the earlier of: Haravan ancestry date vs ERPNext real_order_date
--   3. Use a window function to find the MIN across the split order group
--
-- Output: one row per sales_order_id with the group-level first_order_at.

WITH haravan_ancestry AS (
    SELECT * FROM {{ ref('int_haravan__order_ancestry') }}
),

haravan_orders AS (
    SELECT order_id, created_at
    FROM {{ ref('stg_haravan__orders') }}
),

erpnext_orders AS (
    SELECT
        sales_order_id,
        split_order_group,
        real_order_date,
        haravan_order_id
    FROM {{ ref('stg_erpnext__sales_orders') }}
),

-- Step 1: For each ERPNext order, find its individual root date
with_roots AS (
    SELECT
        e.sales_order_id,
        e.split_order_group,
        LEAST(
            COALESCE(ha.first_order_at, h.created_at),
            e.real_order_date::timestamp
        ) AS individual_root_date
    FROM erpnext_orders e
    LEFT JOIN haravan_orders h ON e.haravan_order_id = h.order_id::text
    LEFT JOIN haravan_ancestry ha ON h.order_id = ha.order_id
)

-- Step 2: Find the earliest date across the entire split group
SELECT
    sales_order_id,
    MIN(individual_root_date) OVER (
        PARTITION BY COALESCE(split_order_group, sales_order_id)
    ) AS first_order_at
FROM with_roots
