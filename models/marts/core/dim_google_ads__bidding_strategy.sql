{{ config(enabled=google_ads_enabled('bidding_budget')) }}

{#- One row per portfolio bidding strategy from the latest snapshot. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'bidding_strategy_id']) }} as bidding_strategy_key,
    customer_id,
    bidding_strategy_id,
    bidding_strategy_name as name,
    bidding_strategy_type as type,
    bidding_strategy_status as status,
    bidding_strategy_target_cpa_target_cpa as target_cpa,
    bidding_strategy_target_roas_target_roas as target_roas,
    bidding_strategy_target_spend_target_spend as target_spend
from {{ ref('stg_google_ads__bid_goal') }}
