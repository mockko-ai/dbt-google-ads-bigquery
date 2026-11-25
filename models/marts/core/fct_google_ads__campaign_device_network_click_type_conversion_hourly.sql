{{ google_ads_fact_config(['hourly', 'conversions'], cluster_by=['campaign_id', 'conversion_action_key']) }}

{#- Campaign conversions by hour and conversion action. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    date_day,
    hour,
    conversion_action,
    device,
    ad_network_type,
    click_type,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__hourly_campaign_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9
