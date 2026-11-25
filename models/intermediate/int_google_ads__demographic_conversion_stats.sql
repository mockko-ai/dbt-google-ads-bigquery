{{ config(enabled=google_ads_enabled('demographics')) }}

{#- Conversion stats of the three demographic reports, unioned with a demographic_type column. -#}

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
        conversion_action,
        click_type,
        device,
        ad_network_type,
        conversions,
        conversions_value
    from {{ ref('stg_google_ads__age_range_conversion_stats') }}

    union all

    select
        'gender' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
        date_day,
        conversion_action,
        click_type,
        device,
        ad_network_type,
        conversions,
        conversions_value
    from {{ ref('stg_google_ads__gender_conversion_stats') }}

    union all

    select
        'parental_status' as demographic_type,
        customer_id,
        campaign_id,
        ad_group_id,
        criterion_id,
        date_day,
        conversion_action,
        click_type,
        device,
        ad_network_type,
        conversions,
        conversions_value
    from {{ ref('stg_google_ads__parental_status_conversion_stats') }}

)
