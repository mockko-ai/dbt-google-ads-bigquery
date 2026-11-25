{{ config(enabled=google_ads_enabled('account', 'conversions', 'reporting')) }}

{#- Reference table: one row per account and day per conversion action. Device, network and click type are summed out.
    It carries conversions only. Clicks and cost would repeat once per action row, so they are not here:
    join to rpt_google_ads__account_daily on the keys and date_day (after summing to one row per entity and day),
    or use rpt_google_ads__account_conversion_daily, which does that for the actions you list in
    var('google_ads_pivot_conversion_actions'). -#}

select
    account.account_key,
    conv.customer_id,
    account.descriptive_name as account_name,
    account.currency_code,
    conv.date_day,
    action.conversion_action_key,
    action.conversion_action_id,
    action.name as conversion_action_name,
    action.category as conversion_action_category,
    conv.conversions,
    conv.conversions_value
from {{ ref('int_google_ads__account_conversions_action_day') }} as conv
left join {{ ref('dim_google_ads__conversion_action') }} as action
    on conv.conversion_action_key = action.conversion_action_key
left join {{ ref('dim_google_ads__account') }} as account
    on conv.customer_id = account.customer_id
