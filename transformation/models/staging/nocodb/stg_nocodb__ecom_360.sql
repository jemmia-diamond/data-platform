{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                     AS ecom_360_id,
    product_id::bigint                                             AS product_id,
    path,
    file_name,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'ecom_360') }}
