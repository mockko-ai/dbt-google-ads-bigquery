{{ google_ads_fact_config(['geo'], cluster_by=['campaign_id', 'ad_group_id', 'geo_target_id']) }}

{#- Rolled up from fct_google_ads__geo_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    customer_id,
    campaign_id,
    ad_group_id,
    geographic_view_country_criterion_id,
    {{ google_ads_extract_id('geo_target_most_specific_location') }} as geo_target_id,
    location_type,
    geo_target_most_specific_location,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value
from {{ ref('fct_google_ads__geo_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
