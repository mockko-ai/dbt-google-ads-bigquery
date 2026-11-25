{#- The narrative payload of the last week parses as JSON, names the currency and lists the spike. -#}

with last_week as (

    select * from {{ ref('rpt_google_ads__narrative_context') }}
    where week_start = date '2025-01-27'

)

select 'payload missing or wrong' as problem
from (
    select
        count(*) as row_count,
        max(json_value(payload_json, '$.currency_code')) as currency_code,
        max(json_value(payload_json, '$.top_anomalies[0].campaign_id')) as top_anomaly_campaign,
        max(json_value(payload_json, '$.data_through_date')) as data_through_date
    from last_week
)
where row_count != 1
    or currency_code != 'USD'
    or top_anomaly_campaign != '101'
    or data_through_date != '2025-01-28'
