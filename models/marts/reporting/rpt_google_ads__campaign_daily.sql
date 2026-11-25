{{ config(enabled=google_ads_enabled('account', 'campaign', 'reporting')) }}

{#- Campaign performance by day, with names and attributes of the campaign and its account.
    One row per customer, campaign and day. -#}

select
    campaign.campaign_key,
    account.account_key,
    fct.customer_id,
    account.descriptive_name as account_name,
    account.currency_code,
    fct.campaign_id,
    campaign.name as campaign_name,
    campaign.status as campaign_status,
    campaign.channel_type,
    campaign.channel_sub_type,
    campaign.bidding_strategy_type,
    campaign.budget_name,
    campaign.budget_amount,
    fct.date_day,
    fct.impressions,
    fct.clicks,
    fct.interactions,
    fct.cost,
    fct.conversions,
    fct.conversions_value,
    fct.view_through_conversions,
    {{ google_ads_ratio_metrics('fct') }}
from {{ ref('fct_google_ads__campaign_daily') }} as fct
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on fct.customer_id = campaign.customer_id
    and fct.campaign_id = campaign.campaign_id
left join {{ ref('dim_google_ads__account') }} as account
    on fct.customer_id = account.customer_id
