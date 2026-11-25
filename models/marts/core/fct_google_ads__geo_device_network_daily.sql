{{ google_ads_fact_config(['geo'], cluster_by=['campaign_id', 'ad_group_id', 'geo_target_id']) }}

{#- Geographic performance. Locations arrive as resource names (geoTargetConstants/<id>) with no place names;
    geo_target_id is parsed from the resource name so it can be joined to the google_ads_geo_target_lookup seed. -#}

select
    customer_id,
    campaign_id,
    ad_group_id,
    geographic_view_country_criterion_id,
    {{ google_ads_extract_id('geo_target_most_specific_location') }} as geo_target_id,
    location_type,
    geo_target_most_specific_location,
    date_day,
    device,
    ad_network_type,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value
from {{ ref('stg_google_ads__geo_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
