{{ config(enabled=google_ads_enabled('account', 'reporting')) }}

{#- Account performance by week (weeks start on Monday). Ratios are recomputed from summed
    numerators and denominators with safe_divide, never averaged. Week-over-week compares with
    the calendar week before (null if the account had no data that week). -#}

{% set base_metrics = ['impressions', 'clicks', 'cost', 'conversions', 'conversions_value'] %}
{% set ratio_metrics = ['ctr', 'cpc', 'cpa', 'roas', 'conversion_rate'] %}

with weekly as (

    select
        customer_id,
        date_trunc(date_day, week(monday)) as week_start,
        sum(impressions) as impressions,
        sum(clicks) as clicks,
        sum(cost) as cost,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        count(distinct date_day) as days_with_data,
        max(date_day) as last_data_date
    from {{ ref('fct_google_ads__account_daily') }}
    group by 1, 2

),

with_ratios as (

    select
        *,
        date_add(week_start, interval 6 day) as week_end,
        safe_divide(clicks, impressions) as ctr,
        safe_divide(cost, clicks) as cpc,
        safe_divide(cost, conversions) as cpa,
        safe_divide(conversions_value, cost) as roas,
        safe_divide(conversions, clicks) as conversion_rate
    from weekly

)

select
    current_week.customer_id,
    current_week.week_start,
    current_week.week_end,
    current_week.week_end < current_date() as is_complete_week,
    current_week.days_with_data,
    current_week.last_data_date,
    {% for m in base_metrics + ratio_metrics %}
    current_week.{{ m }},
    previous_week.{{ m }} as previous_{{ m }},
    current_week.{{ m }} - previous_week.{{ m }} as {{ m }}_wow_change,
    safe_divide(current_week.{{ m }} - previous_week.{{ m }}, previous_week.{{ m }}) as {{ m }}_wow_change_pct{% if not loop.last %},{% endif %}
    {% endfor %}
from with_ratios as current_week
left join with_ratios as previous_week
    on current_week.customer_id = previous_week.customer_id
    and previous_week.week_start = date_sub(current_week.week_start, interval 7 day)
