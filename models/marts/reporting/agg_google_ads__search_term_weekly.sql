{{ config(enabled=google_ads_enabled('search_terms', 'campaign', 'reporting')) }}

{#- Search terms by campaign and week, summed over ads, ad groups, matched keywords, devices and networks.
    Search campaigns only. cost_rank and conversions_rank order the terms of a campaign-week with a fixed
    sort (value descending, then the term) so the output is stable. is_spend_without_conversions marks
    terms that cost money and did not convert. -#}

with weekly as (

    select
        customer_id,
        campaign_id,
        search_term,
        date_trunc(date_day, week(monday)) as week_start,
        sum(impressions) as impressions,
        sum(clicks) as clicks,
        sum(cost) as cost,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value
    from {{ ref('fct_google_ads__search_term_daily') }}
    group by 1, 2, 3, 4

),

with_ratios as (

    select
        *,
        date_add(week_start, interval 6 day) as week_end,
        safe_divide(clicks, impressions) as ctr,
        safe_divide(cost, clicks) as cpc,
        safe_divide(cost, conversions) as cpa,
        safe_divide(conversions_value, cost) as roas
    from weekly

)

select
    current_week.customer_id,
    current_week.campaign_id,
    campaign.name as campaign_name,
    current_week.search_term,
    current_week.week_start,
    current_week.week_end,
    current_week.impressions,
    current_week.clicks,
    current_week.cost,
    current_week.conversions,
    current_week.conversions_value,
    current_week.ctr,
    current_week.cpc,
    current_week.cpa,
    current_week.roas,
    previous_week.cost as previous_cost,
    current_week.cost - previous_week.cost as cost_wow_change,
    safe_divide(current_week.cost - previous_week.cost, previous_week.cost) as cost_wow_change_pct,
    previous_week.conversions as previous_conversions,
    current_week.conversions - previous_week.conversions as conversions_wow_change,
    row_number() over (
        partition by current_week.customer_id, current_week.campaign_id, current_week.week_start
        order by current_week.cost desc, current_week.search_term
    ) as cost_rank,
    row_number() over (
        partition by current_week.customer_id, current_week.campaign_id, current_week.week_start
        order by current_week.conversions desc, current_week.search_term
    ) as conversions_rank,
    current_week.cost > 0 and coalesce(current_week.conversions, 0) = 0 as is_spend_without_conversions
from with_ratios as current_week
left join with_ratios as previous_week
    on current_week.customer_id = previous_week.customer_id
    and current_week.campaign_id = previous_week.campaign_id
    and current_week.search_term = previous_week.search_term
    and previous_week.week_start = date_sub(current_week.week_start, interval 7 day)
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on current_week.customer_id = campaign.customer_id
    and current_week.campaign_id = campaign.campaign_id
