{{ google_ads_fact_config(['pmax'], cluster_by=['campaign_id', 'asset_id']) }}

{#- Asset performance per campaign (used for Performance Max asset detail). campaign_id and asset_id are parsed from
    resource names. -#}

select
    customer_id,
    campaign_id,
    asset_id,
    asset_field_type,
    asset_source,
    date_day,
    device,
    ad_network_type,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(interactions) as interactions,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value
from {{ ref('stg_google_ads__campaign_asset_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
