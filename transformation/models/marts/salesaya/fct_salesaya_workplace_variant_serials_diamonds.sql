{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    diamond_id,
    serial_id                                                            AS variant_serials_id
FROM {{ ref('stg_nocodb__variant_serials_diamonds') }}
