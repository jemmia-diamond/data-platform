{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    name AS user_id,
    email,
    full_name,
    first_name,
    last_name,
    username,
    user_type,
    pancake_id,
    enabled::int::boolean AS is_enabled,
    creation::timestamp AS created_at,
    modified::timestamp AS updated_at,
    owner,
    modified_by,
    _db_updated_at::timestamp AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('erpnext', 'users') }}
