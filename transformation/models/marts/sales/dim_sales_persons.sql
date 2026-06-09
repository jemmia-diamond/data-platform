{{ config(
    materialized='materialized_view',
    schema='marts_sales',
    post_hook=[
      "CREATE INDEX IF NOT EXISTS idx_dsperson_id ON {{ this }} (sales_person_id)",
      "CREATE INDEX IF NOT EXISTS idx_dsperson_region ON {{ this }} (region_name)",
    ]
) }}

WITH sales_persons AS (
    SELECT * FROM {{ ref('int_sales__sales_persons') }}
)

SELECT
    sales_person_id,
    sales_person_name,
    employee_id,
    {{ mask_email('employee_email') }} AS employee_email,
    parent_sales_person,
    commission_rate,
    assigned_lead_count,
    is_enabled,
    operational_status,
    operational_status = 'Active' AS is_active,
    sales_position = 'Presale' AS is_presale,
    region_name,
    city_name,
    store_name,
    sales_position,
    created_at,
    created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS created_at_vn,
    updated_at,
    updated_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS updated_at_vn,
    _db_updated_at
FROM sales_persons
