{{ google_ads_fact_config(['video'], cluster_by=['video_key', 'campaign_id', 'ad_group_id']) }}

{#- Video basic stats and non-click stats combined at their shared grain. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'video_id']) }} as video_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    video_id,
    video_channel_id,
    date_day,
    device,
    ad_network_type,
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
from {{ ref('int_google_ads__video_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
