{{ config(enabled=google_ads_enabled('demographics')) }}

{#- Age range, gender and parental status share one shape, so they are unioned into one
    model with a demographic_type column; demographic_value is the type-specific value. -#}

with unioned as (

    select
        'age_range' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
        ad_group_criterion_age_range_type as demographic_value,
        ad_group_criterion_negative as is_negative,
        ad_group_criterion_status as status,
        ad_group_criterion_bid_modifier as bid_modifier
    from {{ ref('stg_google_ads__age_range') }}

    union all

    select
        'gender' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
        ad_group_criterion_gender_type as demographic_value,
        ad_group_criterion_negative as is_negative,
        ad_group_criterion_status as status,
        ad_group_criterion_bid_modifier as bid_modifier
    from {{ ref('stg_google_ads__gender') }}

    union all

    select
        'parental_status' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
        ad_group_criterion_parental_status_type as demographic_value,
        ad_group_criterion_negative as is_negative,
        ad_group_criterion_status as status,
        cast(null as float64) as bid_modifier
    from {{ ref('stg_google_ads__parental_status') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['demographic_type', 'customer_id', 'ad_group_id', 'criterion_id']) }} as demographic_key,
    *
from unioned
