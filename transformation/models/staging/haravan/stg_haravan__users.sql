{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                               AS user_id,
    first_name,
    last_name,
    email,
    phone,
    account_owner::boolean                                                   AS account_owner,
    receive_announcements::bigint                                            AS receive_announcements,
    user_type,
    permissions,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'users') }}
