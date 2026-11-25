{{ config(enabled=google_ads_enabled('video')) }}

{#- VideoBasicStats and VideoNonClickStats share a grain. They are combined with union all
    and one aggregation, which is a one-to-one combination without a join that could fan out.
    Conversion stats stay staged. -#}

with unioned as (

    select
        customer_id, campaign_id, ad_group_id, ad_id, video_id, video_channel_id,
        date_day, device, ad_network_type,
        impressions, clicks, cost, conversions, conversions_value, view_through_conversions,
        cast(null as float64) as all_conversions,
        cast(null as float64) as all_conversions_value,
        cast(null as float64) as cross_device_conversions,
        cast(null as int64) as engagements,
        cast(null as int64) as video_trueview_views
    from {{ ref('stg_google_ads__video_basic_stats') }}

    union all

    select
        customer_id, campaign_id, ad_group_id, ad_id, video_id, video_channel_id,
        date_day, device, ad_network_type,
        cast(null as int64), cast(null as int64), cast(null as numeric), cast(null as float64), cast(null as float64), cast(null as int64),
        all_conversions, all_conversions_value, cross_device_conversions, engagements, video_trueview_views
    from {{ ref('stg_google_ads__video_non_click_stats') }}

)

select * from unioned
