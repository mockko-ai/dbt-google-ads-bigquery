{{ google_ads_fact_config(['hourly'], cluster_by=['campaign_id']) }}

{#- Campaign performance by hour of day. Grain is the daily campaign grain plus hour and click type. -#}

select
    customer_id,
    campaign_id,
    date_day,
    hour,
    device,
    ad_network_type,
    click_type,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__hourly_campaign_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7
