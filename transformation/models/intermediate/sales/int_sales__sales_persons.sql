{{ config(
    materialized='view',
    schema='intermediate'
) }}

with staging_sales_persons as (
    select * from {{ ref('stg_erpnext__sales_persons') }}
),

-- Step 1: Self-join to bring the parent's sales_person_name down to the employee row
staff_with_parent_config as (
    select
        emp.sales_person_id,
        emp.sales_person_name,
        emp.employee_id,
        emp.employee_email,
        emp.parent_sales_person,
        emp.commission_rate,
        emp.assigned_lead_count,
        emp.is_enabled,
        emp.docstatus,
        emp.created_at,
        emp.updated_at,
        emp._db_updated_at,
        
        case 
            when emp.sales_person_name in ('Presale Team', 'BOD') then emp.sales_person_name
            else par.sales_person_name 
        end as config_name,

        sr.region_name

    from staging_sales_persons emp
    left join staging_sales_persons par 
        on emp.parent_sales_person = par.sales_person_id
    left join {{ ref('int_sales__regions') }} sr
        on emp.sales_region = sr.region_id
    where emp.docstatus < 2 
      and emp.is_group = false
),

-- Step 2: Parse the inherited configuration name using the '-' delimiter
parsed_sales_persons as (
    select
        *,
        trim(split_part(config_name, '-', 1)) as region_code,
        trim(split_part(config_name, '-', 2)) as store_code,
        trim(split_part(config_name, '-', 3)) as raw_position
    from staff_with_parent_config
)

select
    -- Base Fields
    sales_person_id,
    sales_person_name,
    employee_id,
    employee_email,
    parent_sales_person,
    commission_rate,
    assigned_lead_count,
    is_enabled,
    
    -- Operational Status
    case 
        when is_enabled = true and docstatus = 0 then 'Active'
        when is_enabled = false then 'Disabled'
        else 'Inactive'
    end as operational_status,
    
    created_at,
    updated_at,
    _db_updated_at,

    COALESCE(
        region_name,
        CASE region_code
            WHEN 'HN' THEN 'Miền Bắc'
            WHEN 'HCM' THEN 'Miền Nam'
            WHEN 'CT' THEN 'Miền Tây'
            ELSE 'Miền Nam'
        END
    ) AS region_name,

    case 
        when config_name in ('Presale Team', 'BOD') then 'National'
        when region_code = 'HN' then 'Hà Nội'
        when region_code = 'HCM' then 'Hồ Chí Minh'
        when region_code = 'CT' then 'Cần Thơ'
        else region_code 
    end as city_name,

    -- Store Mapping
    case 
        when config_name in ('Presale Team', 'BOD') then 'All Stores'
        when store_code = '63KM' then 'Cửa Hàng số 63 Kim Mã'
        when store_code = '72NCT' then 'Cửa Hàng số 72 Nguyễn Cư Trinh'
        when store_code = '209Đ30T4' then 'Cửa Hàng số 209 Đường 30/04'
        when store_code = '' or store_code is null then 'Unknown'
        else 'Cửa Hàng ' || store_code 
    end as store_name,

    -- Role / Position Mapping
    case 
        when config_name = 'Presale Team' then 'Presale'
        when config_name = 'BOD' then 'Board of Directors'
        when raw_position = '' or raw_position is null then 'Normal Sales'
        else raw_position
    end as sales_position

from parsed_sales_persons