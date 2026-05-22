{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT
    id::bigint                                                               AS event_id,
    verb,
    author,
    subject_id::bigint                                                       AS subject_id,
    subject_type,
    message,
    arguments,
    path,
    created_at::timestamp                                                    AS created_at,
    _db_updated_at::timestamp                                                AS _db_updated_at,
    _dlt_load_id,
    _dlt_id

FROM {{ source('haravan', 'events') }}
