{{ google_ads_fact_config(['shopping', 'conversions'], cluster_by=['campaign_id', 'ad_group_id', 'conversion_action_key']) }}

{#- Shopping conversions by conversion action. The shopping conversion report in the data dictionary has no
    metrics_conversions column, so this fact carries conversions_value and all_conversions only. -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    campaign_id,
    ad_group_id,
    product_item_id,
    product_merchant_id,
    date_day,
    conversion_action,
    click_type,
    device,
    ad_network_type,
    max(product_brand) as product_brand,
    max(product_category_level1) as product_category_level1,
    max(product_category_level2) as product_category_level2,
    max(product_category_level3) as product_category_level3,
    sum(conversions_value) as conversions_value,
    sum(all_conversions) as all_conversions,
    sum(all_conversions_value) as all_conversions_value
from {{ ref('stg_google_ads__shopping_product_conversion_stats') }}
where {{ google_ads_incremental_predicate('date_day') }}
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
