{{ config(
    materialized='materialized_view',
    schema='marts_marketing'
) }}

select
    report_date,
    account_id,
    ad_status,
    ad_id,
    campaign_status,
    fx_adset_audience_name,
    fx_adset_region,
    case
        when fx_ads_goal = 'Sales' and fx_campaign_segment IN ('30-50','50-80','80-120','120-200','>200') then fx_campaign_segment
        else 'Chưa xác định'
    end as price_segment,
    case
        when fx_campaign_fanpage = 'JD' then 'Jemmia Diamond'
        when fx_campaign_fanpage = 'KHX' then 'Kiệt Hột Xoàn'
        when fx_campaign_fanpage = 'AKC' then 'Anh Kim Cương'
        when fx_campaign_fanpage = 'JDHN' then 'Jemmia Diamond Hà Nội'
        when fx_campaign_fanpage = 'QTHX' then 'Quý Tử Hột Xoàn'
        when fx_campaign_fanpage = 'JDCT' then 'Jemmia Diamond Cần Thơ'
        else 'Chưa xác định'
    end as ad_channel,
    case
        when fx_campaign_goal = 'Mess' then 'Mess'
        when fx_campaign_goal = 'View' then 'View'
        when fx_campaign_goal = 'Push' then 'Push'
        else 'Chưa xác định'
    end as ad_objective,
    case
        when fx_ads_goal = 'Sales' then 'Bán Hàng'
        when fx_ads_goal = 'Branding' then 'Branding'
        else 'Chưa xác định'
    end as ad_purpose,
    case
        when fx_campaign_region = 'CT' then 'Cần Thơ'
        when fx_campaign_region = 'HN' then 'Hà Nội'
        when fx_campaign_region = 'HCM' then 'Hồ Chí Minh'
        when fx_campaign_region = 'CT&HCM' then 'Cần Thơ & Hồ Chí Minh'
        when fx_campaign_region = 'ALL' then 'Tất cả'
        when fx_campaign_region = 'VN' then 'Việt Nam'
        else 'Chưa xác định'
    end as ad_region,
    case
        when fx_adset_type IN ('Knowed','Lookalike','New') then fx_adset_type
        else 'Chưa xác định'
    end as ad_type,
    case
        when fx_ads_goal = 'Sales' then fx_ads_categories
        else 'Chưa xác định'
    end as product_category,
    case
        when fx_ads_goal = 'Sales' then fx_ads_product_type
        else 'Chưa xác định'
    end as product_type,
    case
        when fx_adset_audience_name IN ('Knowed','Lookalike','New') then fx_adset_audience_name
        else 'Chưa xác định'
    end as audience_type,
    spend,
    conversation_started as lead,
    leads as qualified_lead
from {{ ref('fct_marketing_facebook_ads_daily') }}
