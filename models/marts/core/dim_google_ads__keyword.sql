{{ config(enabled=google_ads_enabled('keyword')) }}

{#- Keyword ids repeat across ad groups, so the key is customer + ad group + keyword.
    Quality score and its sub-scores only exist for search campaigns. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'keyword_id']) }} as keyword_key,
    customer_id,
    campaign_id,
    ad_group_id,
    keyword_id,
    ad_group_criterion_keyword_text as keyword_text,
    ad_group_criterion_keyword_match_type as match_type,
    ad_group_criterion_negative as is_negative,
    ad_group_criterion_status as status,
    ad_group_criterion_approval_status as approval_status,
    ad_group_criterion_quality_info_quality_score as quality_score,
    ad_group_criterion_quality_info_creative_quality_score as creative_quality_score,
    ad_group_criterion_quality_info_post_click_quality_score as landing_page_quality_score,
    ad_group_criterion_quality_info_search_predicted_ctr as search_predicted_ctr,
    ad_group_criterion_effective_cpc_bid as effective_cpc_bid
from {{ ref('stg_google_ads__keyword') }}
