{{ config(enabled=google_ads_enabled('campaign', 'reporting')) }}

{#- Campaign performance by week (weeks start on Monday), with names from the campaign dim.
    * Ratios use safe_divide on summed numerators and denominators.
    * wow = change against the calendar week before.
    * trailing_4w = average of the four calendar weeks before this one, over the weeks in which the
      campaign had data (a week with no rows counts as missing, not as zero).
    * share_of_account_cost = campaign cost / cost of all campaigns of the customer in the week. -#}

{% set base_metrics = ['impressions', 'clicks', 'cost', 'conversions', 'conversions_value'] %}
{% set ratio_metrics = ['ctr', 'cpc', 'cpa', 'roas', 'conversion_rate'] %}

with weekly as (

    select
        customer_id,
        campaign_id,
        date_trunc(date_day, week(monday)) as week_start,
        sum(impressions) as impressions,
        sum(clicks) as clicks,
        sum(cost) as cost,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        count(distinct date_day) as days_with_data
    from {{ ref('fct_google_ads__campaign_daily') }}
    group by 1, 2, 3

),

with_ratios as (

    select
        *,
        date_add(week_start, interval 6 day) as week_end,
        safe_divide(clicks, impressions) as ctr,
        safe_divide(cost, clicks) as cpc,
        safe_divide(cost, conversions) as cpa,
        safe_divide(conversions_value, cost) as roas,
        safe_divide(conversions, clicks) as conversion_rate,
        safe_divide(cost, sum(cost) over (partition by customer_id, week_start)) as share_of_account_cost,
        {% for m in ['impressions', 'clicks', 'cost', 'conversions', 'conversions_value'] %}
        avg({{ m }}) over trailing_4w as trailing_4w_avg_{{ m }},
        {% endfor %}
        sum(cost) over trailing_4w as trailing_4w_cost_sum,
        sum(conversions) over trailing_4w as trailing_4w_conversions_sum,
        sum(conversions_value) over trailing_4w as trailing_4w_conversions_value_sum
    from weekly
    window trailing_4w as (
        partition by customer_id, campaign_id
        order by unix_date(week_start)
        range between 28 preceding and 7 preceding
    )

),

enriched as (

    select
        *,
        safe_divide(trailing_4w_cost_sum, trailing_4w_conversions_sum) as trailing_4w_cpa,
        safe_divide(trailing_4w_conversions_value_sum, trailing_4w_cost_sum) as trailing_4w_roas
    from with_ratios

)

select
    current_week.customer_id,
    current_week.campaign_id,
    campaign.name as campaign_name,
    campaign.channel_type,
    campaign.status as campaign_status,
    current_week.week_start,
    current_week.week_end,
    current_week.week_end < current_date() as is_complete_week,
    current_week.days_with_data,
    current_week.share_of_account_cost,
    previous_week.share_of_account_cost as previous_share_of_account_cost,
    {% for m in base_metrics + ratio_metrics %}
    current_week.{{ m }},
    previous_week.{{ m }} as previous_{{ m }},
    current_week.{{ m }} - previous_week.{{ m }} as {{ m }}_wow_change,
    safe_divide(current_week.{{ m }} - previous_week.{{ m }}, previous_week.{{ m }}) as {{ m }}_wow_change_pct,
    {% endfor %}
    {% for m in base_metrics %}
    current_week.trailing_4w_avg_{{ m }},
    safe_divide(current_week.{{ m }} - current_week.trailing_4w_avg_{{ m }}, current_week.trailing_4w_avg_{{ m }}) as {{ m }}_vs_trailing_4w_pct,
    {% endfor %}
    current_week.trailing_4w_cpa,
    safe_divide(current_week.cpa - current_week.trailing_4w_cpa, current_week.trailing_4w_cpa) as cpa_vs_trailing_4w_pct,
    current_week.trailing_4w_roas,
    safe_divide(current_week.roas - current_week.trailing_4w_roas, current_week.trailing_4w_roas) as roas_vs_trailing_4w_pct
from enriched as current_week
left join enriched as previous_week
    on current_week.customer_id = previous_week.customer_id
    and current_week.campaign_id = previous_week.campaign_id
    and previous_week.week_start = date_sub(current_week.week_start, interval 7 day)
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on current_week.customer_id = campaign.customer_id
    and current_week.campaign_id = campaign.campaign_id
