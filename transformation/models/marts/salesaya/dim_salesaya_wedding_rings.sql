{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH wedding_rings AS (
    SELECT * FROM {{ ref('int_catalog__wedding_rings') }}
)

SELECT
    wedding_ring_id                                                      AS id,
    title
FROM wedding_rings
