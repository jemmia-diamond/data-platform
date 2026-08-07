{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                     AS set_id,
    set_name,
    design_codes,
    haravan_product_id::bigint                                     AS haravan_product_id,
    haravan_variant_id::bigint                                     AS haravan_variant_id,
    main_image_link,
    {{ safe_cast_timestamp('database_created_at') }}               AS created_at,
    {{ safe_cast_timestamp('database_updated_at') }}               AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'sets') }}
