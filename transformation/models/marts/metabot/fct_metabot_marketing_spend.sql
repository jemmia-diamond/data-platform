{{ config(materialized='materialized_view', schema='marts_metabot') }}

-- Metabot marketing spend. Grain: 1 row = 1 date × 1 platform.
-- Source: 3 staging ads tables (Facebook/Google/TikTok) UNION'd + date×platform grid from dim_metabot_dates.
-- Full decouple from marts_marketing.fct_marketing_omnichannel_daily.

WITH platform_list AS (
    SELECT 'Facebook' AS platform_name
    UNION SELECT 'Google'
    UNION SELECT 'TikTok'
),

date_platform_grid AS (
    SELECT
        d.date,
        p.platform_name
    FROM {{ ref('dim_metabot_dates') }} d
    CROSS JOIN platform_list p
    WHERE d.date <= CURRENT_DATE
      AND d.date >= '2020-01-01'
),

union_metrics AS (
    SELECT report_date, 'Facebook' AS platform_name, SUM(spend) AS spend, SUM(clicks) AS clicks, SUM(impressions) AS impressions
    FROM {{ ref('stg_facebook_ads__custom_campaign_daily') }}
    GROUP BY 1, 2
    UNION ALL
    SELECT report_date, 'Google' AS platform_name, SUM(spend), SUM(clicks), SUM(impressions)
    FROM {{ ref('stg_google_ads__campaign_daily') }}
    GROUP BY 1, 2
    UNION ALL
    SELECT report_date, 'TikTok' AS platform_name, SUM(spend), SUM(clicks), SUM(impressions)
    FROM {{ ref('stg_tiktok_ads__campaign_daily') }}
    GROUP BY 1, 2
)

SELECT
    md5(concat(grid.date, '_', grid.platform_name)) AS marketing_perf_key,
    grid.date AS report_date,
    grid.platform_name,
    COALESCE(m.spend, 0) AS total_spend_vnd,
    COALESCE(m.clicks, 0) AS total_clicks,
    COALESCE(m.impressions, 0) AS total_impressions,
    COALESCE(m.spend, 0) / NULLIF(m.clicks, 0) AS cpc_vnd,
    COALESCE(m.spend, 0) / NULLIF(m.impressions, 0) * 1000 AS cpm_vnd,
    m.clicks / NULLIF(m.impressions, 0) * 100 AS ctr_pct
FROM date_platform_grid grid
LEFT JOIN union_metrics m
    ON grid.date = m.report_date
    AND grid.platform_name = m.platform_name
