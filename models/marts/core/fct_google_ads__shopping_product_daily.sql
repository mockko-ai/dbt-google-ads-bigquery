{{ google_ads_fact_config(['shopping'], cluster_by=['campaign_id', 'ad_group_id', 'product_item_id']) }}

{#- The source grain has about 30 product columns. This fact aggregates to campaign, ad group, item, merchant,
    date, device and network, and carries brand and category levels 1 to 3 (max() per item; they should not vary). -#}

select
    customer_id,
    campaign_id,
    ad_group_id,
    product_item_id,
    product_merchant_id,
    date_day,
    device,
    ad_network_type,
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
from {{ ref('stg_google_ads__shopping_product_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
