{{ config(enabled=google_ads_enabled('account', 'campaign', 'conversions', 'reporting')) }}

{#- Reference table: one row per campaign and day per conversion action and attribution event type. Device, network and click type are summed out.
    It carries conversions only. Clicks and cost would repeat once per action row, so they are not here:
    join to rpt_google_ads__campaign_daily on the keys and date_day (after summing to one row per entity and day),
    or use rpt_google_ads__campaign_conversion_daily, which does that for the actions you list in
    var('google_ads_pivot_conversion_actions'). -#}

with conv as (

    select
        customer_id,
        campaign_id,
        date_day,
        conversion_action_key,
        conversion_attribution_event_type,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value
    from {{ ref('fct_google_ads__campaign_network_attribution_conversion_daily') }}
    group by 1, 2, 3, 4, 5

)

select
    campaign.campaign_key,
    account.account_key,
    conv.customer_id,
    account.descriptive_name as account_name,
    account.currency_code,
    conv.campaign_id,
    campaign.name as campaign_name,
    campaign.status as campaign_status,
    campaign.channel_type,
    conv.date_day,
    action.conversion_action_key,
    action.conversion_action_id,
    action.name as conversion_action_name,
    action.category as conversion_action_category,
    conv.conversion_attribution_event_type,
    conv.conversions,
    conv.conversions_value
from conv
left join {{ ref('dim_google_ads__conversion_action') }} as action
    on conv.conversion_action_key = action.conversion_action_key
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on conv.customer_id = campaign.customer_id
    and conv.campaign_id = campaign.campaign_id
left join {{ ref('dim_google_ads__account') }} as account
    on conv.customer_id = account.customer_id
