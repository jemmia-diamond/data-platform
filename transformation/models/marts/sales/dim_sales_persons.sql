{{ config(
    materialized='table',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_dsperson_id ON {{ this }} (sales_person_id)",
      "CREATE INDEX IF NOT EXISTS idx_dsperson_region ON {{ this }} (sales_region_name)",
    ]
) }}

WITH sales_persons AS (
    SELECT * FROM {{ ref('int_sales__sales_persons') }}
)

SELECT
    sales_person_id,
    sales_person_name,
    employee_id,
    employee_email,
    parent_sales_person,
    commission_rate,
    assigned_lead_count,
    is_enabled,
    operational_status,
    operational_status = 'Active' AS is_active,
    sales_position = 'Presale' AS is_presale,
    sales_region_name,
    region_name,
    store_name,
    sales_position,
    created_at,
    updated_at,
    _db_updated_at
FROM sales_persons
