{{ config(
    materialized='view',
    schema='intermediate'
) }}

SELECT * FROM {{ ref('stg_erpnext__customers') }}
