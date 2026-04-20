{{ config(
    materialized='view',
    schema='staging'
) }}

WITH latest_adsets AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id 
            ORDER BY updated_time DESC, _airbyte_extracted_at DESC
        ) AS row_num
    FROM {{ source('facebook_marketing', 'ad_sets') }}
),
parsed_names AS (
    SELECT 
        *,
        split_part(name, '_', 1) as raw_type,
        split_part(name, '_', 2) as raw_audience,
        split_part(name, '_', 3) as raw_region,
        split_part(name, '_', 4) as raw_gender,
        split_part(name, '_', 5) as raw_age_range
    FROM latest_adsets
    WHERE row_num = 1
),
logic_applied AS (
    SELECT 
        *,
        CASE 
            WHEN raw_type IN ('Knowed', 'Lookalike', 'New') THEN raw_type 
            ELSE 'Chưa xác định' 
        END AS fx_adset_type
    FROM parsed_names
)
SELECT 
    id AS adset_id,
    campaign_id,
    account_id,
    name AS adset_name,
    effective_status,
    
    fx_adset_type,
    CASE WHEN fx_adset_type != 'Chưa xác định' THEN raw_audience ELSE 'Chưa xác định' END AS fx_adset_audience_name,
    CASE WHEN fx_adset_type != 'Chưa xác định' THEN raw_region ELSE 'Chưa xác định' END AS fx_adset_region,
    CASE WHEN fx_adset_type != 'Chưa xác định' THEN raw_gender ELSE 'Chưa xác định' END AS fx_adset_gender,
    CASE WHEN fx_adset_type != 'Chưa xác định' THEN raw_age_range ELSE 'Chưa xác định' END AS fx_adset_age_range,

    (targeting ->> 'age_min')::int AS target_age_min,
    (targeting ->> 'age_max')::int AS target_age_max,
    targeting -> 'geo_locations' -> 'regions' AS target_regions,
    targeting -> 'publisher_platforms' AS target_platforms,

    (learning_stage_info ->> 'attribution_windows') AS attribution_windows,

    daily_budget / 100.0 AS daily_budget,
    lifetime_budget / 100.0 AS lifetime_budget,
    budget_remaining / 100.0 AS budget_remaining,

    start_time,
    end_time,
    updated_time,
    _airbyte_extracted_at AS staging_updated_at

FROM logic_applied
