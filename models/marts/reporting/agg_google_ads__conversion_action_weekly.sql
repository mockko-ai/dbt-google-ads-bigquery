{{ config(enabled=google_ads_enabled('campaign', 'conversions', 'reporting')) }}

{#- Which conversion actions drive conversions, per campaign and week, and how the mix shifted.
    share_of_campaign_conversions = action conversions / all conversions of the campaign in the week.
    mix_shift_pp is this week's share minus last week's share, in share points (0.05 = 5 points).
    Rolled up to campaign, action and week before any comparison, so nothing is joined at action grain
    to clicks or cost. -#}

with weekly as (

    select
        customer_id,
        campaign_id,
        conversion_action_key,
        date_trunc(date_day, week(monday)) as week_start,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value
    from {{ ref('fct_google_ads__campaign_network_attribution_conversion_daily') }}
    group by 1, 2, 3, 4

),

with_share as (

    select
        *,
        date_add(week_start, interval 6 day) as week_end,
        safe_divide(conversions, sum(conversions) over (partition by customer_id, campaign_id, week_start)) as share_of_campaign_conversions
    from weekly

)

select
    current_week.customer_id,
    current_week.campaign_id,
    campaign.name as campaign_name,
    current_week.conversion_action_key,
    action.name as conversion_action_name,
    action.category as conversion_action_category,
    current_week.week_start,
    current_week.week_end,
    current_week.conversions,
    previous_week.conversions as previous_conversions,
    current_week.conversions - previous_week.conversions as conversions_wow_change,
    safe_divide(current_week.conversions - previous_week.conversions, previous_week.conversions) as conversions_wow_change_pct,
    current_week.conversions_value,
    previous_week.conversions_value as previous_conversions_value,
    current_week.conversions_value - previous_week.conversions_value as conversions_value_wow_change,
    safe_divide(current_week.conversions_value - previous_week.conversions_value, previous_week.conversions_value) as conversions_value_wow_change_pct,
    current_week.share_of_campaign_conversions,
    previous_week.share_of_campaign_conversions as previous_share_of_campaign_conversions,
    current_week.share_of_campaign_conversions - coalesce(previous_week.share_of_campaign_conversions, 0) as mix_shift_pp
from with_share as current_week
left join with_share as previous_week
    on current_week.customer_id = previous_week.customer_id
    and current_week.campaign_id = previous_week.campaign_id
    and current_week.conversion_action_key = previous_week.conversion_action_key
    and previous_week.week_start = date_sub(current_week.week_start, interval 7 day)
left join {{ ref('dim_google_ads__conversion_action') }} as action
    on current_week.conversion_action_key = action.conversion_action_key
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on current_week.customer_id = campaign.customer_id
    and current_week.campaign_id = campaign.campaign_id
