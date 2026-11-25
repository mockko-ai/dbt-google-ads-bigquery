{{ google_ads_fact_config(['shopping'], cluster_by=['campaign_id', 'ad_group_id', 'product_item_id']) }}

{#- Rolled up from fct_google_ads__shopping_product_device_network_daily: ad_network_type, device summed out. Additive metrics only. -#}

select
    customer_id,
    campaign_id,
    ad_group_id,
    product_item_id,
    product_merchant_id,
    date_day,
    max(product_brand) as product_brand,
    max(product_category_level1) as product_category_level1,
    max(product_category_level2) as product_category_level2,
    max(product_category_level3) as product_category_level3,
    sum(impressions) as impressions,
    sum(clicks) as clicks,
    sum(cost) as cost,
    sum(conversions) as conversions,
    sum(conversions_value) as conversions_value,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value
from {{ ref('fct_google_ads__shopping_product_device_network_daily') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6
