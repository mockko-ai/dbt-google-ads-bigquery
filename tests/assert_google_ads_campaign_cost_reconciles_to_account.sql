{{ config(enabled=google_ads_enabled('account', 'campaign')) }}

{#- Summed campaign cost per day must match account cost per day within 0.5 percent.
    Returns the days that do not. -#}

with account as (

    select customer_id, date_day, sum(cost) as account_cost
    from {{ ref('fct_google_ads__account_device_network_daily') }}
    group by 1, 2

),

campaign as (

    select customer_id, date_day, sum(cost) as campaign_cost
    from {{ ref('fct_google_ads__campaign_device_network_daily') }}
    group by 1, 2

)

select
    account.customer_id,
    account.date_day,
    account.account_cost,
    coalesce(campaign.campaign_cost, 0) as campaign_cost
from account
left join campaign
    on account.customer_id = campaign.customer_id
    and account.date_day = campaign.date_day
where abs(account.account_cost - coalesce(campaign.campaign_cost, 0))
    > 0.005 * greatest(abs(account.account_cost), 0.01)
