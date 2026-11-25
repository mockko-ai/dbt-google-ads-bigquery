{{ google_ads_fact_config(['keyword'], cluster_by=['keyword_key', 'campaign_id', 'ad_group_id']) }}

{#- Additive metrics only. `slot` (top vs other placement) is summed out. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'keyword_id']) }} as keyword_key,
    customer_id,
    campaign_id,
    ad_group_id,
    keyword_id,
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
from {{ ref('stg_google_ads__keyword_basic_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
