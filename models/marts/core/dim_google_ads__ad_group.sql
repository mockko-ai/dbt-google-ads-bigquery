{{ config(enabled=google_ads_enabled('ad_group')) }}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'ad_group_id']) }} as ad_group_key,
    customer_id,
    campaign_id,
    ad_group_id,
    ad_group_name as name,
    ad_group_status as status,
    ad_group_type as type,
    ad_group_cpc_bid as cpc_bid,
    ad_group_effective_target_cpa as effective_target_cpa,
    ad_group_effective_target_roas as effective_target_roas
from {{ ref('stg_google_ads__ad_group') }}
