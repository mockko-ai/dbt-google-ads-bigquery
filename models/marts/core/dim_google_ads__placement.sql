{{ config(enabled=google_ads_enabled('placements')) }}

{#- One row per placement (website, app or channel) targeted or excluded in an ad group. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id', 'criterion_id']) }} as placement_key,
    customer_id,
    campaign_id,
    ad_group_id,
    criterion_id,
    ad_group_criterion_placement_url as placement_url,
    ad_group_criterion_negative as is_negative,
    ad_group_criterion_status as status,
    ad_group_criterion_bid_modifier as bid_modifier
from {{ ref('stg_google_ads__placement') }}
