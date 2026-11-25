{{ config(enabled=google_ads_enabled('audiences')) }}

{#- Ad group and campaign level audience targets in one model with a level column.
    criterion_id is a string because the campaign level source stores it as a string.
    The stats tables carry no audience name, and the audience reports have no id that links
    to ads_Audience, so no name is joined here. -#}

with unioned as (

    select
        'ad_group' as level,
        customer_id,
        cast(null as int64) as campaign_id,
        ad_group_id,
        cast(criterion_id as string) as criterion_id,
        ad_group_criterion_status as status,
        ad_group_criterion_bid_modifier as bid_modifier
    from {{ ref('stg_google_ads__ad_group_audience') }}

    union all

    select
        'campaign' as level,
        customer_id,
        campaign_id,
        cast(null as int64) as ad_group_id,
        cast(criterion_id as string) as criterion_id,
        cast(null as string) as status,
        safe_cast(campaign_criterion_bid_modifier as float64) as bid_modifier
    from {{ ref('stg_google_ads__campaign_audience') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['level', 'customer_id', 'campaign_id', 'ad_group_id', 'criterion_id']) }} as audience_target_key,
    *
from unioned
