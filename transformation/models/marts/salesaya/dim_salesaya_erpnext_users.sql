{{ config(
    materialized='materialized_view',
    schema='marts_salesaya'
) }}

SELECT
    user_id                                                              AS name,
    email,
    pancake_id
FROM {{ ref('stg_erpnext__users') }}
