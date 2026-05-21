{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint AS moissanite_id,
    product_group,
    shape,
    {{ safe_cast_numeric('length') }} AS length,
    {{ safe_cast_numeric('width') }} AS width,
    color,
    clarity,
    fluorescence,
    cut,
    polish,
    symmetry,
    product_group_norm,
    shape_norm,
    length_norm,
    width_norm,
    color_norm,
    clarity_norm,
    fluorescence_norm,
    cut_norm,
    polish_norm,
    symmetry_norm,
    haravan_product_id::bigint,
    haravan_variant_id::bigint,
    {{ safe_cast_boolean('auto_create') }} AS auto_create,
    title,
    price::numeric,
    barcode,
    moissanite_serials::int,
    {{ safe_cast_timestamp('database_updated_at') }} AS updated_at,
    _db_updated_at::timestamp,
    _dlt_load_id,
    _dlt_id

FROM {{ source('nocodb', 'moissanite') }}
