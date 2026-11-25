{{ config(enabled=google_ads_enabled('ad')) }}

{#- Ad ids repeat across ad groups, so the key is customer + ad group + ad. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id']) }} as ad_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_id,
    ad_group_ad_ad_type as ad_type,
    ad_group_ad_ad_name as name,
    ad_group_ad_ad_strength as ad_strength,
    ad_group_ad_status as status,
    ad_group_ad_policy_summary_approval_status as approval_status,
    ad_group_ad_ad_final_urls as final_urls,
    ad_group_ad_ad_final_mobile_urls as final_mobile_urls,
    ad_group_ad_ad_display_url as display_url,
    ad_group_ad_ad_responsive_search_ad_headlines as responsive_search_ad_headlines,
    ad_group_ad_ad_responsive_search_ad_descriptions as responsive_search_ad_descriptions,
    ad_group_ad_ad_responsive_search_ad_path1 as responsive_search_ad_path1,
    ad_group_ad_ad_responsive_search_ad_path2 as responsive_search_ad_path2
from {{ ref('stg_google_ads__ad') }}
