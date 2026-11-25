{{ google_ads_fact_config(['hourly'], cluster_by=['campaign_id']) }}

{#- Rolled up from fct_google_ads__campaign_device_network_click_type_hourly: ad_network_type, click_type, device summed out. Additive metrics only. -#}

select
    customer_id,
    campaign_id,
    date_day,
    hour,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('fct_google_ads__campaign_device_network_click_type_hourly') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4
