{{ google_ads_fact_config(['video'], cluster_by=['video_key', 'campaign_id', 'ad_group_id']) }}

{#- Rolled up from fct_google_ads__video_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'video_id']) }} as video_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    video_id,
    video_channel_id,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value,
    sum(cross_device_conversions) as cross_device_conversions,
    sum(engagements) as engagements,
    sum(video_trueview_views) as video_trueview_views
from {{ ref('fct_google_ads__video_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
