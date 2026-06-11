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
    {{ filter_text('sales_person_name') }} AS sales_person_name,
    employee_id,
    {{ mask_email('employee_email') }} AS employee_email,
    {{ filter_text('parent_sales_person', 'Không có cấp trên') }} AS parent_sales_person,
    commission_rate,
    assigned_lead_count,
    is_enabled,
    {{ filter_text('operational_status') }} AS operational_status,
    operational_status = 'Active' AS is_active,
    sales_position = 'Presale' AS is_presale,
    {{ filter_text('region_name', 'Chưa gán vùng') }} AS region_name,
    {{ filter_text('city_name', 'Chưa gán thành phố') }} AS city_name,
    {{ filter_text('store_name', 'Chưa gán cửa hàng') }} AS store_name,
    {{ filter_text('sales_position') }} AS sales_position,
    created_at,
    created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS created_at_vn,
    updated_at,
    updated_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh' AS updated_at_vn,
    _db_updated_at
FROM sales_persons
