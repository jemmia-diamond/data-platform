{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot sales person dimension. Grain: 1 row = 1 sales person.
-- Source: int_sales__sales_persons (full decouple from marts_sales).

SELECT
    sp.sales_person_id,
    sp.sales_person_name,
    {{ mask_email('sp.employee_email') }} AS employee_email,
    sp.region_name,
    sp.city_name,
    sp.store_name,
    sp.sales_position,
    (sp.operational_status = 'Active') AS is_active,
    (sp.sales_position = 'Presale') AS is_presale,
    sp.commission_rate,
    sp.assigned_lead_count
FROM {{ ref('int_sales__sales_persons') }} sp
