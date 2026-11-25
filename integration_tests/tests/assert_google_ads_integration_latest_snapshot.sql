{#- The seeds hold an old snapshot with names ending in " (old)". Dims must show the latest one only. -#}

select 'campaign' as entity, name from {{ ref('dim_google_ads__campaign') }} where name like '%(old)%'
union all
select 'account', descriptive_name from {{ ref('dim_google_ads__account') }} where descriptive_name like '%(old)%'
union all
select 'ad_group', name from {{ ref('dim_google_ads__ad_group') }} where name like '%(old)%'
