{{ config(
    materialized='materialized_view',
    schema='marts_sales'
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
    region_name,
    store_name,
    sales_position,
    created_at,
    updated_at,
    _db_updated_at
FROM sales_persons
