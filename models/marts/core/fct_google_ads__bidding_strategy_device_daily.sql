{{ google_ads_fact_config(['bidding_budget'], cluster_by=['bidding_strategy_key']) }}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'bidding_strategy_id']) }} as bidding_strategy_key,
    customer_id,
    bidding_strategy_id,
    date_day,
    device,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__bid_goal_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5
