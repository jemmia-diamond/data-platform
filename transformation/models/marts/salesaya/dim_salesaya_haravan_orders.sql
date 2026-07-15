{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    order_id                                                             AS id,
    order_name                                                           AS name
FROM {{ ref('stg_haravan__orders') }}
