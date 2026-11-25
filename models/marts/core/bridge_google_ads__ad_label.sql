{{ config(enabled=google_ads_enabled('ad')) }}

{#- One row per ad and label. The label table carries the ad as a composite resource name
    (adGroupId~adId), already split into ad_group_id and ad_id in staging. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id']) }} as ad_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'ad_id', 'label_id']) }} as ad_label_key,
    customer_id,
    ad_group_id,
    ad_id,
    label_id,
    label_name
from {{ ref('stg_google_ads__ad_label') }}
