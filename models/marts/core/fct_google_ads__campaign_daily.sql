{{ google_ads_fact_config(['campaign'], cluster_by=['customer_id', 'campaign_id']) }}

{#- True campaign-day grain: device and network are summed out of the segmented model. Additive metrics only. -#}

select
    customer_id,
    campaign_id,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions
from {{ ref('fct_google_ads__campaign_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3
