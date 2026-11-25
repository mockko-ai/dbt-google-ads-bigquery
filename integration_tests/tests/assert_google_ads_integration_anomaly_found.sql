{#- Campaign 101 spends ten times more on the last seeded day (2025-01-28). It must be flagged. -#}

select 'spike on campaign 101 was not flagged' as problem
from (
    select count(*) as flagged
    from {{ ref('rpt_google_ads__anomalies') }}
    where campaign_id = 101 and date_day = date '2025-01-28' and is_cost_anomaly
)
where flagged = 0
