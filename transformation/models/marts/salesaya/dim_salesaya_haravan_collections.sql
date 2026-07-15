{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

WITH haravan_collections AS (
    SELECT * FROM {{ ref('int_catalog__haravan_collections') }}
)

SELECT
    haravan_collection_id                                               AS id,
    title,
    discount_type,
    discount_value,
    start_date,
    end_date
FROM haravan_collections
