{{ config(enabled=google_ads_enabled('demographics')) }}

{#- One row per demographic criterion (age range, gender or parental status) per ad group. -#}

select
    demographic_key,
    demographic_type,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    demographic_value,
    is_negative,
    status,
    bid_modifier
from {{ ref('int_google_ads__demographic') }}
