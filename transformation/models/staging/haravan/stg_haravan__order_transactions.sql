{{ config(
    materialized='view',
    schema='staging'
) }}

WITH unnested AS (
    SELECT
        id::bigint AS order_id,
        jsonb_array_elements(transactions) AS txn
    FROM {{ source('haravan', 'orders') }}
    WHERE transactions IS NOT NULL AND jsonb_typeof(transactions) = 'array'
)

SELECT
    (txn->>'id')::bigint AS transaction_id,
    order_id,
    (txn->>'amount')::numeric AS amount,
    txn->>'gateway' AS payment_gateway,
    txn->>'kind' AS transaction_kind, -- capture, pending, sale
    (txn->>'created_at')::timestamp AS transaction_created_at,
    (txn->>'user_id')::bigint AS user_id,
    txn->>'status' AS transaction_status
FROM unnested
