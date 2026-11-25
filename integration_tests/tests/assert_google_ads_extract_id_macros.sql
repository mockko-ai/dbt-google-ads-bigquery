{#- Unit tests for google_ads_extract_id: plain trailing ids, composite (~) names, and bad input.
    Returns the cases whose result differs from the expected value. -#}

with cases as (

    select 'customers/1234567890/campaigns/111' as resource_name, 111 as expected_plain, cast(null as int64) as expected_part1, cast(null as int64) as expected_part2, cast(null as int64) as expected_part3
    union all select 'customers/1234567890/adGroupAds/222~333', null, 222, 333, null
    union all select 'customers/1234567890/assetGroupAssets/1~2~HEADLINE', null, 1, 2, null
    union all select 'customers/1234567890/adGroupAdLabels/10~20~30', null, 10, 20, 30
    union all select 'customers/1234567890/assets/444', 444, 444, null, null
    union all select 'not a resource name', null, null, null, null
    union all select cast(null as string), null, null, null, null

)

select *
from (
    select
        *,
        {{ google_ads_extract_id('resource_name') }} as actual_plain,
        {{ google_ads_extract_id('resource_name', 1) }} as actual_part1,
        {{ google_ads_extract_id('resource_name', 2) }} as actual_part2,
        {{ google_ads_extract_id('resource_name', 3) }} as actual_part3
    from cases
)
where actual_plain is distinct from expected_plain
    or actual_part1 is distinct from expected_part1
    or actual_part2 is distinct from expected_part2
    or actual_part3 is distinct from expected_part3
