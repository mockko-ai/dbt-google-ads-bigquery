{{ google_ads_fact_config(['search_terms', 'conversions'], cluster_by=['ad_key', 'campaign_id', 'conversion_action_key']) }}

{#- Search term performance split by conversion action. Do not join this model to
    fct_google_ads__search_term_daily; roll it up to search term and day first. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id']) }} as ad_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    search_term,
    search_term_match_type,
    keyword_ad_group_criterion,
    date_day,
    conversion_action,
    device,
    ad_network_type,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__search_query_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
