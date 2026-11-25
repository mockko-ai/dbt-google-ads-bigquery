{{ config(enabled=google_ads_enabled('ad_group')) }}

{#- One row per ad group and label. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'label_id']) }} as ad_group_label_key,
    customer_id,
    ad_group_id,
    label_id,
    label_name
from {{ ref('stg_google_ads__ad_group_label') }}
