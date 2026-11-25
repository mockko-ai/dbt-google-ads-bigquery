{{ config(enabled=google_ads_enabled('ad_group', 'conversions')) }}

{#- Conversions in the basic stats must match the conversion stats summed to ad_group and day
    (tolerance: var google_ads_conversion_tolerance, default 0.5 percent). The conversion
    stats are rolled up first, never joined at conversion-action grain. -#}

with basic as (

    select customer_id, ad_group_id, date_day, sum(conversions) as basic_conversions
    from {{ ref('fct_google_ads__ad_group_device_network_daily') }}
    group by 1, 2, 3

),

by_action as (

    select customer_id, ad_group_id, date_day, sum(conversions) as action_conversions
    from {{ ref('int_google_ads__ad_group_conversions_entity_day') }}
    group by 1, 2, 3

)

select
    basic.customer_id,
    basic.ad_group_id,
    basic.date_day,
    basic.basic_conversions,
    coalesce(by_action.action_conversions, 0) as action_conversions
from basic
left join by_action
    on basic.customer_id = by_action.customer_id
    and basic.ad_group_id = by_action.ad_group_id
    and basic.date_day = by_action.date_day
where abs(basic.basic_conversions - coalesce(by_action.action_conversions, 0))
    > {{ var('google_ads_conversion_tolerance', 0.005) }} * greatest(abs(basic.basic_conversions), 1)
