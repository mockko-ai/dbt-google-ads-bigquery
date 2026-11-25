{{ config(enabled=google_ads_enabled('account', 'conversions')) }}

{#- Account conversions by conversion action and day. There is no account conversion fact, so the
    staging model is rolled up here: device, network, click type and slot are summed out. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    date_day,
    conversion_action,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__account_conversion_stats') }}
group by 1, 2, 3, 4
