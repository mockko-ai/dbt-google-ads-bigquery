{{ google_ads_fact_config(['impression_share'], cluster_by=['customer_id']) }}

{#- EXCEPTION to "facts hold additive metrics only": the impression share and lost-share columns are ratios
    reported by Google Ads. They are passed through at the source grain (account, day, network) and must never be
    summed or averaged across rows. The additive columns beside them are safe to sum. -#}

select
    customer_id,
    date_day,
    ad_network_type,
    search_impression_share,
    search_exact_match_impression_share,
    search_budget_lost_impression_share,
    search_rank_lost_impression_share,
    content_impression_share,
    content_budget_lost_impression_share,
    content_rank_lost_impression_share,
    all_conversions,
    all_conversions_value,
    cross_device_conversions,
    engagements,
    invalid_clicks,
    video_trueview_views
from {{ ref('stg_google_ads__account_non_click_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
