{{ config(enabled=google_ads_enabled('video')) }}

{#- One row per video per ad group, from the latest snapshot. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'video_id']) }} as video_key,
    customer_id,
    campaign_id,
    ad_group_id,
    video_id,
    video_title as title,
    video_duration_millis as duration_millis,
    ad_group_ad_status as ad_status
from {{ ref('stg_google_ads__video') }}
