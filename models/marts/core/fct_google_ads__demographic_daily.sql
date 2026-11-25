{{ google_ads_fact_config(['demographics'], cluster_by=['demographic_key', 'campaign_id', 'ad_group_id']) }}

{#- Age range, gender and parental status performance, unioned with a demographic_type column. -#}

select
    demographic_key,
    demographic_type,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    date_day,
    device,
    ad_network_type,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(view_through_conversions) as view_through_conversions
from {{ ref('int_google_ads__demographic_basic_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
