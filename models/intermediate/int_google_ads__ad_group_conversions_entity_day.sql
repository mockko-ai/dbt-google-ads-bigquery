{{ config(enabled=google_ads_enabled('ad_group', 'conversions')) }}

{#- Conversion rows multiply by conversion action. Roll them up to ad_group and day before joining
    to anything that carries clicks or cost, otherwise those metrics are repeated per action. -#}

select
    customer_id,
    ad_group_id,
    date_day,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__ad_group_conversion_stats') }}
group by 1, 2, 3
