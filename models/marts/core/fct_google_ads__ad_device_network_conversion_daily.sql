{{ google_ads_fact_config(['ad', 'conversions'], cluster_by=['ad_key', 'ad_group_id', 'conversion_action_key']) }}

{#- One row per conversion action. Rows multiply by conversion action, so never join this
    model to a basic stats fact: roll it up to entity and day first
    (see the int_google_ads__*_conversions_entity_day models). `slot` is summed out. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id']) }} as ad_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    date_day,
    conversion_action,
    device,
    click_type,
    ad_network_type,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__ad_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
