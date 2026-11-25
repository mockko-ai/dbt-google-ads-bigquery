{{ config(enabled=google_ads_enabled('keyword', 'conversions')) }}

{#- Conversion rows multiply by conversion action. Roll them up to keyword and day before joining
    to anything that carries clicks or cost, otherwise those metrics are repeated per action. -#}

select
    customer_id,
    ad_group_id,
    keyword_id,
    date_day,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__keyword_conversion_stats') }}
group by 1, 2, 3, 4
