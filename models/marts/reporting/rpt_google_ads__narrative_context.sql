{{ config(enabled=google_ads_enabled('account', 'campaign', 'reporting')) }}

{#- One row per customer and week with `payload_json`: the small, pre-computed, labeled input for a
    narrative written by a person or an LLM. Nothing here calls an LLM.

    The reader should never see raw stats tables or do arithmetic. It may only quote numbers in the payload.
    Every list is ranked in SQL with a fixed sort (value, then id or name as tie-break) and a fixed cap,
    so the same data always gives the same payload and the token count stays small.

    Sections: period, data_through_date, totals (value, previous, change, change_pct, unit),
    top campaign movers up and down by cost and by conversions (top 5 each), top anomalies (5),
    top conversion actions (5, when the conversions family is on), search terms with spend and zero
    conversions (top 10, when the search_terms family is on), and a short definitions object.
    payload_hash identifies the payload; log it next to any generated text. -#}

{% set has_conversions = google_ads_enabled('conversions') %}
{% set has_search_terms = google_ads_enabled('search_terms') %}
{% set mover_cap = 5 %}

with account_weekly as (

    select
        weekly.*,
        account.descriptive_name as account_name,
        account.currency_code,
        account.time_zone
    from {{ ref('agg_google_ads__account_weekly') }} as weekly
    left join {{ ref('dim_google_ads__account') }} as account
        on weekly.customer_id = account.customer_id

),

freshness as (

    select customer_id, max(date_day) as data_through_date
    from {{ ref('fct_google_ads__account_daily') }}
    group by 1

),

-- ---------------------------------------------------------------- campaign movers
campaign_weeks as (

    select customer_id, campaign_id, week_start from {{ ref('agg_google_ads__campaign_weekly') }}
    union distinct
    select customer_id, campaign_id, date_add(week_start, interval 7 day) from {{ ref('agg_google_ads__campaign_weekly') }}

),

campaign_moves as (

    select
        account_weekly.customer_id,
        account_weekly.week_start,
        campaign_weeks.campaign_id,
        coalesce(current_week.campaign_name, previous_week.campaign_name) as campaign_name,
        coalesce(current_week.cost, 0) as cost,
        coalesce(previous_week.cost, 0) as previous_cost,
        coalesce(current_week.cost, 0) - coalesce(previous_week.cost, 0) as cost_change,
        coalesce(current_week.conversions, 0) as conversions,
        coalesce(previous_week.conversions, 0) as previous_conversions,
        coalesce(current_week.conversions, 0) - coalesce(previous_week.conversions, 0) as conversions_change
    from account_weekly
    inner join campaign_weeks
        on account_weekly.customer_id = campaign_weeks.customer_id
        and account_weekly.week_start = campaign_weeks.week_start
    left join {{ ref('agg_google_ads__campaign_weekly') }} as current_week
        on campaign_weeks.customer_id = current_week.customer_id
        and campaign_weeks.campaign_id = current_week.campaign_id
        and campaign_weeks.week_start = current_week.week_start
    left join {{ ref('agg_google_ads__campaign_weekly') }} as previous_week
        on campaign_weeks.customer_id = previous_week.customer_id
        and campaign_weeks.campaign_id = previous_week.campaign_id
        and previous_week.week_start = date_sub(campaign_weeks.week_start, interval 7 day)

),

campaign_ranked as (

    select
        *,
        row_number() over (partition by customer_id, week_start order by cost_change desc, campaign_id) as cost_up_rank,
        row_number() over (partition by customer_id, week_start order by cost_change asc, campaign_id) as cost_down_rank,
        row_number() over (partition by customer_id, week_start order by conversions_change desc, campaign_id) as conversions_up_rank,
        row_number() over (partition by customer_id, week_start order by conversions_change asc, campaign_id) as conversions_down_rank
    from campaign_moves

),

movers as (

    select
        customer_id,
        week_start,
        {% for metric, direction, sign in [('cost', 'up', '>'), ('cost', 'down', '<'), ('conversions', 'up', '>'), ('conversions', 'down', '<')] %}
        ifnull(array_agg(
            if({{ metric }}_{{ direction }}_rank <= {{ mover_cap }} and {{ metric }}_change {{ sign }} 0,
                struct(
                    campaign_id,
                    campaign_name,
                    round({{ metric }}, 2) as {{ metric }},
                    round(previous_{{ metric }}, 2) as previous_{{ metric }},
                    round({{ metric }}_change, 2) as change,
                    round(safe_divide({{ metric }}_change, previous_{{ metric }}), 4) as change_pct
                ),
                null)
            ignore nulls
            order by {{ metric }}_{{ direction }}_rank
        ), []) as {{ metric }}_{{ direction }}{% if not loop.last %},{% endif %}
        {% endfor %}
    from campaign_ranked
    group by 1, 2

),

-- ---------------------------------------------------------------- anomalies
anomaly_ranked as (

    select
        customer_id,
        date_trunc(date_day, week(monday)) as week_start,
        *,
        row_number() over (
            partition by customer_id, date_trunc(date_day, week(monday))
            order by anomaly_score desc, date_day, campaign_id
        ) as anomaly_rank
    from {{ ref('rpt_google_ads__anomalies') }}
    where is_anomaly

),

anomalies as (

    select
        customer_id,
        week_start,
        array_agg(
            struct(
                date_day as date,
                campaign_id,
                campaign_name,
                round(cost, 2) as cost,
                round(cost_zscore, 2) as cost_zscore,
                round(conversions, 2) as conversions,
                round(conversions_zscore, 2) as conversions_zscore,
                round(cpa, 2) as cpa,
                round(cpa_zscore, 2) as cpa_zscore,
                is_cost_anomaly,
                is_conversions_anomaly,
                is_cpa_anomaly
            )
            order by anomaly_rank
            limit {{ mover_cap }}
        ) as top_anomalies
    from anomaly_ranked
    group by 1, 2

),

{% if has_conversions %}
-- ---------------------------------------------------------------- conversion actions
action_weekly as (

    select
        customer_id,
        week_start,
        conversion_action_key,
        any_value(conversion_action_name) as conversion_action_name,
        any_value(conversion_action_category) as conversion_action_category,
        sum(conversions) as conversions,
        sum(previous_conversions) as previous_conversions
    from {{ ref('agg_google_ads__conversion_action_weekly') }}
    group by 1, 2, 3

),

action_ranked as (

    select
        *,
        safe_divide(conversions, sum(conversions) over (partition by customer_id, week_start)) as share_of_conversions,
        safe_divide(previous_conversions, sum(previous_conversions) over (partition by customer_id, week_start)) as previous_share_of_conversions,
        row_number() over (partition by customer_id, week_start order by conversions desc, conversion_action_name) as action_rank
    from action_weekly

),

actions as (

    select
        customer_id,
        week_start,
        array_agg(
            struct(
                conversion_action_name as name,
                conversion_action_category as category,
                round(conversions, 2) as conversions,
                round(previous_conversions, 2) as previous_conversions,
                round(conversions - coalesce(previous_conversions, 0), 2) as change,
                round(share_of_conversions, 4) as share_of_conversions,
                round(share_of_conversions - coalesce(previous_share_of_conversions, 0), 4) as share_change
            )
            order by action_rank
            limit {{ mover_cap }}
        ) as top_conversion_actions
    from action_ranked
    where action_rank <= {{ mover_cap }}
    group by 1, 2

),
{% endif %}

{% if has_search_terms %}
-- ---------------------------------------------------------------- wasted search terms
term_ranked as (

    select
        customer_id,
        week_start,
        campaign_id,
        campaign_name,
        search_term,
        cost,
        clicks,
        row_number() over (
            partition by customer_id, week_start
            order by cost desc, campaign_id, search_term
        ) as term_rank
    from {{ ref('agg_google_ads__search_term_weekly') }}
    where is_spend_without_conversions

),

terms as (

    select
        customer_id,
        week_start,
        array_agg(
            struct(
                search_term,
                campaign_id,
                campaign_name,
                round(cost, 2) as cost,
                clicks,
                0 as conversions
            )
            order by term_rank
            limit 10
        ) as top_search_terms_without_conversions
    from term_ranked
    where term_rank <= 10
    group by 1, 2

),
{% endif %}

payload as (

    select
        account_weekly.customer_id,
        account_weekly.week_start,
        account_weekly.week_end,
        account_weekly.is_complete_week,
        freshness.data_through_date,
        to_json_string(struct(
            account_weekly.customer_id as customer_id,
            account_weekly.account_name as account_name,
            account_weekly.currency_code as currency_code,
            account_weekly.time_zone as time_zone,
            struct(
                account_weekly.week_start as week_start,
                account_weekly.week_end as week_end,
                date_sub(account_weekly.week_start, interval 7 day) as comparison_week_start,
                date_sub(account_weekly.week_end, interval 7 day) as comparison_week_end,
                account_weekly.is_complete_week as is_complete_week,
                account_weekly.days_with_data as days_with_data
            ) as period,
            freshness.data_through_date as data_through_date,
            struct(
                {% for metric, unit in [
                    ('cost', 'account_weekly.currency_code'),
                    ('clicks', "'count'"),
                    ('impressions', "'count'"),
                    ('conversions', "'count'"),
                    ('conversions_value', 'account_weekly.currency_code'),
                    ('ctr', "'ratio'"),
                    ('cpc', 'account_weekly.currency_code'),
                    ('cpa', 'account_weekly.currency_code'),
                    ('roas', "'ratio'"),
                    ('conversion_rate', "'ratio'")] %}
                struct(
                    round(account_weekly.{{ metric }}, 4) as value,
                    round(account_weekly.previous_{{ metric }}, 4) as previous,
                    round(account_weekly.{{ metric }}_wow_change, 4) as change,
                    round(account_weekly.{{ metric }}_wow_change_pct, 4) as change_pct,
                    {{ unit }} as unit
                ) as {{ metric }}{% if not loop.last %},{% endif %}
                {% endfor %}
            ) as totals,
            struct(
                ifnull(movers.cost_up, []) as cost_up,
                ifnull(movers.cost_down, []) as cost_down,
                ifnull(movers.conversions_up, []) as conversions_up,
                ifnull(movers.conversions_down, []) as conversions_down
            ) as top_campaign_movers,
            ifnull(anomalies.top_anomalies, []) as top_anomalies,
            {% if has_conversions %}
            ifnull(actions.top_conversion_actions, []) as top_conversion_actions,
            {% endif %}
            {% if has_search_terms %}
            ifnull(terms.top_search_terms_without_conversions, []) as top_search_terms_without_conversions,
            {% endif %}
            struct(
                'Weeks run Monday to Sunday in the account time zone.' as week,
                'Change is this week minus the previous week; change_pct is change divided by the previous value.' as change,
                'CTR is clicks divided by impressions.' as ctr,
                'CPC is cost divided by clicks.' as cpc,
                'CPA is cost divided by conversions.' as cpa,
                'ROAS is conversions_value divided by cost.' as roas,
                'Conversion rate is conversions divided by clicks.' as conversion_rate,
                'Cost and conversions_value are in currency_code. Conversions can be fractional.' as units,
                'Movers are the campaigns with the largest increase or decrease in the metric versus the previous week.' as movers,
                'An anomaly is a campaign-day whose cost, conversions or CPA is at least the threshold number of standard deviations away from its trailing 28 days.' as anomaly,
                'A search term without conversions had cost above zero and no conversions in the week.' as search_terms_without_conversions,
                'Only quote numbers that appear in this payload. Do not describe days after data_through_date.' as usage
            ) as definitions
        )) as payload_json
    from account_weekly
    left join freshness
        on account_weekly.customer_id = freshness.customer_id
    left join movers
        on account_weekly.customer_id = movers.customer_id
        and account_weekly.week_start = movers.week_start
    left join anomalies
        on account_weekly.customer_id = anomalies.customer_id
        and account_weekly.week_start = anomalies.week_start
    {% if has_conversions %}
    left join actions
        on account_weekly.customer_id = actions.customer_id
        and account_weekly.week_start = actions.week_start
    {% endif %}
    {% if has_search_terms %}
    left join terms
        on account_weekly.customer_id = terms.customer_id
        and account_weekly.week_start = terms.week_start
    {% endif %}

)

select
    customer_id,
    week_start,
    week_end,
    is_complete_week,
    data_through_date,
    payload_json,
    to_hex(md5(payload_json)) as payload_hash
from payload
