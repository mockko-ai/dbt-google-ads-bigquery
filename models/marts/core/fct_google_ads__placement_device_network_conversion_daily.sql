{{ google_ads_fact_config(['placements', 'conversions'], cluster_by=['placement_key', 'campaign_id', 'conversion_action_key']) }}

{#- Placement conversions split by conversion action. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'criterion_id']) }} as placement_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    date_day,
    conversion_action,
    click_type,
    device,
    ad_network_type,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__placement_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
