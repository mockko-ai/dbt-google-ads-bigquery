{{ config(enabled=google_ads_enabled('campaign')) }}

{#- One row per campaign and label. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'campaign_id', 'label_id']) }} as campaign_label_key,
    customer_id,
    campaign_id,
    label_id,
    label_name
from {{ ref('stg_google_ads__campaign_label') }}
