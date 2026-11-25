{{ config(enabled=google_ads_enabled('pmax')) }}

{#- Bridge between asset groups and assets, with the asset's role (field type) in the group. Ids are parsed
    from resource names. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'asset_group_id', 'asset_id', 'asset_group_asset_field_type']) }} as asset_group_asset_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'asset_group_id']) }} as asset_group_key,
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'asset_id']) }} as asset_key,
    customer_id,
    asset_group_id,
    asset_id,
    asset_group_asset_field_type as field_type,
    asset_group_asset_source as source,
    asset_group_asset_policy_summary_approval_status as approval_status
from {{ ref('stg_google_ads__asset_group_asset') }}
