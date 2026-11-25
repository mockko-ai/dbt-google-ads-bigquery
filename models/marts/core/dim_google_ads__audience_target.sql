{{ config(enabled=google_ads_enabled('audiences')) }}

{#- One row per audience target at ad group or campaign level (level column).
    No audience name is available: see the model description. -#}

select
    audience_target_key,
    level,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    status,
    bid_modifier
from {{ ref('int_google_ads__audience_target') }}
