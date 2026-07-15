{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    diamond_id,
    haravan_collection_id
FROM {{ ref('stg_nocodb__diamonds_haravan_collection') }}
