{#- Row counts the synthetic seeds must produce: slot is summed out and nothing fans out.
    2 campaigns x 28 days x 2 devices x 1 network = 112 campaign rows; 4 ad groups -> 224;
    account level 56. Returns a row for every model whose count is wrong. -#}

select 'fct_google_ads__campaign_daily' as model, count(*) as actual_rows, 112 as expected_rows
from {{ ref('fct_google_ads__campaign_daily') }}
having count(*) != 112
union all
select 'fct_google_ads__ad_group_daily', count(*), 224
from {{ ref('fct_google_ads__ad_group_daily') }}
having count(*) != 224
union all
select 'fct_google_ads__account_daily', count(*), 56
from {{ ref('fct_google_ads__account_daily') }}
having count(*) != 56
union all
select 'dim_google_ads__ad', count(*), 4
from {{ ref('dim_google_ads__ad') }}
having count(*) != 4
union all
select 'dim_google_ads__keyword', count(*), 4
from {{ ref('dim_google_ads__keyword') }}
having count(*) != 4
union all
select 'dim_google_ads__conversion_action', count(*), 2
from {{ ref('dim_google_ads__conversion_action') }}
having count(*) != 2
