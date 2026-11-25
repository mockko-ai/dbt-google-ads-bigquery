{{ google_ads_fact_config(['pmax'], cluster_by=['campaign_id', 'asset_id']) }}

{#- Rolled up from fct_google_ads__campaign_asset_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    customer_id,
    campaign_id,
    asset_id,
    asset_field_type,
    asset_source,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('fct_google_ads__campaign_asset_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6
