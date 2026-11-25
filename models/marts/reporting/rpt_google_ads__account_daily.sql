{{ config(enabled=google_ads_enabled('account', 'reporting')) }}

{#- Account performance by day, with the account name and attributes. One row per customer and day.
    All measures are additive; ratios are safe_divide of the summed numerators and denominators. -#}

select
    account.account_key,
    fct.customer_id,
    account.descriptive_name as account_name,
    account.currency_code,
    account.time_zone,
    account.is_manager,
    fct.date_day,
    fct.impressions,
    fct.clicks,
    fct.interactions,
    fct.cost,
    fct.conversions,
    fct.conversions_value,
    fct.view_through_conversions,
    {{ google_ads_ratio_metrics('fct') }}
from {{ ref('fct_google_ads__account_daily') }} as fct
left join {{ ref('dim_google_ads__account') }} as account
    on fct.customer_id = account.customer_id
