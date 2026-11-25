{{ google_ads_fact_config(['bidding_budget'], cluster_by=['campaign_id', 'campaign_budget_id']) }}

{#- Daily spend per budget and campaign. Pair with budget_amount on dim_google_ads__campaign for pacing. -#}

select
    customer_id,
    campaign_budget_id,
    campaign_id,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value,
    sum(view_through_conversions) as view_through_conversions
from {{ ref('stg_google_ads__budget_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4
