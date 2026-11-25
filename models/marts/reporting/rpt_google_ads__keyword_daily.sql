{{ config(enabled=google_ads_enabled('account', 'campaign', 'ad_group', 'keyword', 'reporting')) }}

{#- Keyword performance by day, with names and attributes of the keyword, ad group, campaign and account.
    One row per customer, ad group, keyword and day (keyword ids repeat across ad groups). -#}

select
    keyword.keyword_key,
    ad_group.ad_group_key,
    campaign.campaign_key,
    account.account_key,
    fct.customer_id,
    account.descriptive_name as account_name,
    account.currency_code,
    fct.campaign_id,
    campaign.name as campaign_name,
    campaign.status as campaign_status,
    campaign.channel_type,
    fct.ad_group_id,
    ad_group.name as ad_group_name,
    ad_group.status as ad_group_status,
    fct.keyword_id,
    keyword.keyword_text,
    keyword.match_type,
    keyword.is_negative,
    keyword.status as keyword_status,
    keyword.quality_score,
    fct.date_day,
    fct.impressions,
    fct.clicks,
    fct.interactions,
    fct.cost,
    fct.conversions,
    fct.conversions_value,
    fct.view_through_conversions,
    {{ google_ads_ratio_metrics('fct') }}
from {{ ref('fct_google_ads__keyword_daily') }} as fct
left join {{ ref('dim_google_ads__keyword') }} as keyword
    on fct.customer_id = keyword.customer_id
    and fct.ad_group_id = keyword.ad_group_id
    and fct.keyword_id = keyword.keyword_id
left join {{ ref('dim_google_ads__ad_group') }} as ad_group
    on fct.customer_id = ad_group.customer_id
    and fct.ad_group_id = ad_group.ad_group_id
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on fct.customer_id = campaign.customer_id
    and fct.campaign_id = campaign.campaign_id
left join {{ ref('dim_google_ads__account') }} as account
    on fct.customer_id = account.customer_id
