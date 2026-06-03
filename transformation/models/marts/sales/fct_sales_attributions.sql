{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_fsa_order_id ON {{ this }} (order_id)",
      "CREATE INDEX IF NOT EXISTS idx_fsa_sales_person_key ON {{ this }} (sales_person_key)",
      "CREATE INDEX IF NOT EXISTS idx_fsa_date ON {{ this }} USING brin (order_date)",
    ]
) }}

WITH orders AS (
    SELECT * FROM {{ ref('fct_sales_orders') }}
),

teams AS (
    SELECT * FROM {{ ref('int_sales__sales_teams') }}
),

teams_with_quality AS (
    SELECT
        teams.*,
        SUM(allocated_percentage) OVER (
            PARTITION BY erp_sales_order_id
        ) AS total_order_allocated_percentage
    FROM teams
)

SELECT
    o.order_id || ':' || t.order_sales_team_id AS attribution_key,
    o.order_id,
    o.erp_order_id,
    o.order_number,
    t.order_sales_team_id,
    t.sales_person_id AS sales_person_key,
    o.customer_id,
    o.customer_name,
    o.real_created_at AS business_date,
    o.order_date,
    o.sales_channel,

    t.allocated_percentage,
    t.total_order_allocated_percentage,
    t.total_order_allocated_percentage < 99.99
        OR t.total_order_allocated_percentage > 100.01
        AS is_order_allocation_percent_anomaly,
    t.allocated_amount,
    t.incentives_amount,

    o.gross_amount * COALESCE(t.allocated_percentage, 100) / 100 AS allocated_gross_amount,
    o.net_amount * COALESCE(t.allocated_percentage, 100) / 100 AS allocated_net_amount,
    o.total_qty * COALESCE(t.allocated_percentage, 100) / 100 AS allocated_quantity,

    o.payment_status,
    o.fulfillment_status,
    o.processing_status

FROM orders o
INNER JOIN teams_with_quality t
    ON o.erp_order_id = t.erp_sales_order_id
