{{ config(enabled=google_ads_enabled('campaign', 'reporting')) }}

{#- Campaign-day cost, conversions and CPA against the trailing 28 calendar days (the 28 days before the
    day, current day excluded; only days that have rows count). A metric is flagged when its z-score,
    (value - trailing mean) / trailing standard deviation, is beyond var('google_ads_anomaly_zscore')
    (default 3). Needs at least 7 trailing days with data, otherwise the z-score is null and nothing is flagged.
    CPA only exists on days with conversions. -#}

{% set threshold = var('google_ads_anomaly_zscore', 3) %}

with daily as (

    select
        customer_id,
        campaign_id,
        date_day,
        sum(cost) as cost,
        sum(conversions) as conversions,
        safe_divide(sum(cost), sum(conversions)) as cpa
    from {{ ref('fct_google_ads__campaign_daily') }}
    group by 1, 2, 3

),

baseline as (

    select
        *,
        {% for m in ['cost', 'conversions', 'cpa'] %}
        avg({{ m }}) over trailing_28d as baseline_{{ m }}_avg,
        stddev_samp({{ m }}) over trailing_28d as baseline_{{ m }}_stddev,
        count({{ m }}) over trailing_28d as baseline_{{ m }}_days{% if not loop.last %},{% endif %}
        {% endfor %}
    from daily
    window trailing_28d as (
        partition by customer_id, campaign_id
        order by unix_date(date_day)
        range between 28 preceding and 1 preceding
    )

),

scored as (

    select
        *,
        {% for m in ['cost', 'conversions', 'cpa'] %}
        if(baseline_{{ m }}_days >= 7, safe_divide({{ m }} - baseline_{{ m }}_avg, baseline_{{ m }}_stddev), null) as {{ m }}_zscore{% if not loop.last %},{% endif %}
        {% endfor %}
    from baseline

),

flagged as (

    select
        *,
        abs(cost_zscore) >= {{ threshold }} as is_cost_anomaly,
        abs(conversions_zscore) >= {{ threshold }} as is_conversions_anomaly,
        abs(cpa_zscore) >= {{ threshold }} as is_cpa_anomaly
    from scored

)

select
    flagged.customer_id,
    flagged.campaign_id,
    campaign.name as campaign_name,
    flagged.date_day,
    flagged.cost,
    flagged.baseline_cost_avg,
    flagged.baseline_cost_stddev,
    flagged.cost_zscore,
    flagged.conversions,
    flagged.baseline_conversions_avg,
    flagged.baseline_conversions_stddev,
    flagged.conversions_zscore,
    flagged.cpa,
    flagged.baseline_cpa_avg,
    flagged.baseline_cpa_stddev,
    flagged.cpa_zscore,
    coalesce(flagged.is_cost_anomaly, false) as is_cost_anomaly,
    coalesce(flagged.is_conversions_anomaly, false) as is_conversions_anomaly,
    coalesce(flagged.is_cpa_anomaly, false) as is_cpa_anomaly,
    coalesce(flagged.is_cost_anomaly or flagged.is_conversions_anomaly or flagged.is_cpa_anomaly, false) as is_anomaly,
    greatest(
        coalesce(abs(flagged.cost_zscore), 0),
        coalesce(abs(flagged.conversions_zscore), 0),
        coalesce(abs(flagged.cpa_zscore), 0)
    ) as anomaly_score,
    {{ threshold }} as zscore_threshold
from flagged
left join {{ ref('dim_google_ads__campaign') }} as campaign
    on flagged.customer_id = campaign.customer_id
    and flagged.campaign_id = campaign.campaign_id
