{{ google_ads_fact_config(['search_terms'], cluster_by=['ad_key', 'campaign_id', 'ad_group_id']) }}

{#- Rolled up from fct_google_ads__search_term_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id']) }} as ad_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    search_term,
    search_term_match_type,
    keyword_ad_group_criterion,
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
from {{ ref('fct_google_ads__search_term_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
