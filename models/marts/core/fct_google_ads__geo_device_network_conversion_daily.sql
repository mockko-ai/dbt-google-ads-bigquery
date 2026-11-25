{{ google_ads_fact_config(['geo', 'conversions'], cluster_by=['campaign_id', 'ad_group_id', 'conversion_action_key']) }}

{#- Geographic conversions split by conversion action. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    ad_group_id,
    geographic_view_country_criterion_id,
    {{ google_ads_extract_id('geo_target_most_specific_location') }} as geo_target_id,
    location_type,
    geo_target_most_specific_location,
    date_day,
    conversion_action,
    device,
    ad_network_type,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value
from {{ ref('stg_google_ads__geo_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
