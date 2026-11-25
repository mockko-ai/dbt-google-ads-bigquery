{{ config(enabled=true) }}

{#- Calendar from var('google_ads_date_spine_start') to one year ahead. Weeks start on Monday. -#}

with spine as (

    {{ dbt_utils.date_spine(
        datepart='day',
        start_date="cast('" ~ var('google_ads_date_spine_start', '2018-01-01') ~ "' as date)",
        end_date="date_add(current_date(), interval 1 year)"
    ) }}

),

days as (

    select cast(date_day as date) as date_day from spine

)

select
    date_day,
    date_trunc(date_day, week(monday)) as week_start,
    date_trunc(date_day, month) as month,
    date_trunc(date_day, quarter) as quarter,
    extract(year from date_day) as year,
    format_date('%A', date_day) as day_of_week,
    date_trunc(date_day, week(monday)) = date_trunc(current_date(), week(monday)) as is_current_week,
    date_add(date_trunc(date_day, week(monday)), interval 6 day) < current_date() as is_complete_week
from days
