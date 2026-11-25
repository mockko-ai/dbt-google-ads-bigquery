{{ google_ads_fact_config(['audiences'], cluster_by=['audience_target_key', 'campaign_id', 'ad_group_id']) }}

{#- Rolled up from fct_google_ads__audience_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    audience_target_key,
    level,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions
from {{ ref('fct_google_ads__audience_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7
