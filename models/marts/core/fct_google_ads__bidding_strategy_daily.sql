{{ google_ads_fact_config(['bidding_budget'], cluster_by=['bidding_strategy_key']) }}

{#- Rolled up from fct_google_ads__bidding_strategy_device_daily: device summed out. Additive metrics only. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'bidding_strategy_id']) }} as bidding_strategy_key,
    customer_id,
    bidding_strategy_id,
    date_day,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('fct_google_ads__bidding_strategy_device_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4
