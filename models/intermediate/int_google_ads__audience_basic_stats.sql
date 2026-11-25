{{ config(enabled=google_ads_enabled('audiences')) }}

{#- Ad group and campaign audience basic stats with a level column. -#}

with unioned as (

    select
        'ad_group' as level,
        customer_id,
        cast(null as int64) as campaign_id,
        ad_group_id,
        cast(criterion_id as string) as criterion_id,
        date_day,
        device,
        ad_network_type,
        impressions,
        clicks,
        interactions,
        cost,
        conversions,
        conversions_value,
        view_through_conversions
    from {{ ref('stg_google_ads__ad_group_audience_basic_stats') }}

    union all

    select
        'campaign' as level,
        customer_id,
        campaign_id,
        cast(null as int64) as ad_group_id,
        cast(criterion_id as string) as criterion_id,
        date_day,
        device,
        ad_network_type,
        impressions,
        clicks,
        interactions,
        cost,
        conversions,
        conversions_value,
        view_through_conversions
    from {{ ref('stg_google_ads__campaign_audience_basic_stats') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['level', 'customer_id', 'campaign_id', 'ad_group_id', 'criterion_id']) }} as audience_target_key,
    *
from unioned
