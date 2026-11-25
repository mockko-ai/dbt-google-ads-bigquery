{{ config(enabled=google_ads_enabled('demographics')) }}

{#- Basic stats of the three demographic reports, unioned with a demographic_type column. -#}

select
    {{ dbt_utils.generate_surrogate_key(['demographic_type', 'customer_id', 'ad_group_id', 'criterion_id']) }} as demographic_key,
    *
from (

    select
        'age_range' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
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
    from {{ ref('stg_google_ads__age_range_basic_stats') }}

    union all

    select
        'gender' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
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
    from {{ ref('stg_google_ads__gender_basic_stats') }}

    union all

    select
        'parental_status' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
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
    from {{ ref('stg_google_ads__parental_status_basic_stats') }}

)
