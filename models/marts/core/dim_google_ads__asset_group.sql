{{ config(enabled=google_ads_enabled('pmax')) }}

{#- One row per Performance Max asset group. Performance Max has no ad groups or ads; the campaign id is parsed
    from the asset group's campaign resource name. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'asset_group_id']) }} as asset_group_key,
    customer_id,
    campaign_id,
    asset_group_id,
    asset_group_name as name,
    asset_group_status as status,
    asset_group_final_urls as final_urls,
    asset_group_final_mobile_urls as final_mobile_urls
from {{ ref('stg_google_ads__asset_group') }}
