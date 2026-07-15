{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    wedding_ring_id                                                      AS id
FROM {{ ref('stg_nocodb__wedding_rings') }}
