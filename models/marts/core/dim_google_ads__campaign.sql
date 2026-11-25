{{ config(enabled=google_ads_enabled('campaign')) }}

{#- The campaign table carries its budget as a resource name
    (customers/<customer_id>/campaignBudgets/<budget_id>); the trailing number is the join key
    to ads_Budget. If the budget table has no match, the amounts stored on the campaign row are used. -#}

with campaign as (

    select
        *,
        {{ google_ads_extract_id('campaign_campaign_budget') }} as campaign_budget_id
    from {{ ref('stg_google_ads__campaign') }}

),

budget as (

    select * from {{ ref('stg_google_ads__budget') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['campaign.customer_id', 'campaign.campaign_id']) }} as campaign_key,
    campaign.customer_id,
    campaign.campaign_id,
    campaign.campaign_name as name,
    campaign.campaign_status as status,
    campaign.campaign_serving_status as serving_status,
    campaign.campaign_advertising_channel_type as channel_type,
    campaign.campaign_advertising_channel_sub_type as channel_sub_type,
    campaign.campaign_bidding_strategy_type as bidding_strategy_type,
    campaign.bidding_strategy_name,
    campaign.campaign_budget_id,
    budget.campaign_budget_name as budget_name,
    coalesce(budget.campaign_budget_amount, campaign.campaign_budget_amount) as budget_amount,
    coalesce(budget.campaign_budget_period, campaign.campaign_budget_period) as budget_period,
    budget.campaign_budget_delivery_method as budget_delivery_method,
    coalesce(budget.campaign_budget_explicitly_shared, campaign.campaign_budget_explicitly_shared) as is_budget_shared,
    campaign.campaign_start_date_time as start_datetime,
    campaign.campaign_end_date_time as end_datetime
from campaign
left join budget
    on campaign.customer_id = budget.customer_id
    and campaign.campaign_budget_id = budget.campaign_budget_id
