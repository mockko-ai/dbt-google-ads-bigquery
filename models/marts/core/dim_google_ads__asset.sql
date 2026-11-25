{{ config(enabled=google_ads_enabled('pmax')) }}

{#- One row per asset. The asset reports carry no customer_id; it is read from the source table name. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'asset_id']) }} as asset_key,
    customer_id,
    asset_id,
    asset_name as name,
    asset_type as type,
    asset_source as source,
    asset_final_urls as final_urls
from {{ ref('stg_google_ads__asset') }}
