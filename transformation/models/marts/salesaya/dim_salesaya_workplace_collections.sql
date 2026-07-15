{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    collection_id                                                        AS id,
    collection_name
FROM {{ ref('stg_nocodb__collections') }}
