{{ google_ads_fact_config(['search_terms'], cluster_by=['ad_key', 'campaign_id', 'ad_group_id']) }}

{#- Search term data only exists for search campaigns. keyword_ad_group_criterion is the
    matched keyword's resource name; it is part of the grain because the same term can match
    different keywords. Additive metrics only. -#}

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
    device,
    ad_network_type,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value,
    sum(view_through_conversions) as view_through_conversions
from {{ ref('stg_google_ads__search_query_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
