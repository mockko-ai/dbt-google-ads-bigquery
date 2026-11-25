{{ config(enabled=google_ads_enabled('conversions')) }}

{#- Google Ads has no conversion-action table in the transfer. Conversion actions only exist as
    segment columns inside the *ConversionStats tables, so the distinct set is taken from
    every conversion stats staging model that is switched on. The latest name and category
    win, so a renamed action shows its new name on old days. -#}

with all_actions as (

    {% set sources = [] %}
    {% if google_ads_enabled('campaign', 'conversions') %}{% do sources.append('stg_google_ads__campaign_conversion_stats') %}{% endif %}
    {% if google_ads_enabled('ad_group', 'conversions') %}{% do sources.append('stg_google_ads__ad_group_conversion_stats') %}{% endif %}
    {% if google_ads_enabled('ad', 'conversions') %}{% do sources.append('stg_google_ads__ad_conversion_stats') %}{% endif %}
    {% if google_ads_enabled('keyword', 'conversions') %}{% do sources.append('stg_google_ads__keyword_conversion_stats') %}{% endif %}
    {% if google_ads_enabled('search_terms', 'conversions') %}{% do sources.append('stg_google_ads__search_query_conversion_stats') %}{% endif %}
    {% for family, model in [
        ('demographics', 'stg_google_ads__age_range_conversion_stats'),
        ('demographics', 'stg_google_ads__gender_conversion_stats'),
        ('demographics', 'stg_google_ads__parental_status_conversion_stats'),
        ('audiences', 'stg_google_ads__ad_group_audience_conversion_stats'),
        ('audiences', 'stg_google_ads__campaign_audience_conversion_stats'),
        ('placements', 'stg_google_ads__placement_conversion_stats'),
        ('geo', 'stg_google_ads__geo_conversion_stats'),
        ('shopping', 'stg_google_ads__shopping_product_conversion_stats'),
        ('hourly', 'stg_google_ads__hourly_campaign_conversion_stats'),
    ] %}
        {% if google_ads_enabled(family, 'conversions') %}{% do sources.append(model) %}{% endif %}
    {% endfor %}

    {% if sources | length == 0 %}
    select
        cast(null as int64) as customer_id,
        cast(null as string) as conversion_action,
        cast(null as string) as conversion_action_name,
        cast(null as string) as conversion_action_category,
        cast(null as date) as date_day
    from (select 1) where false
    {% endif %}

    {% for source in sources %}
    select customer_id, conversion_action, conversion_action_name, conversion_action_category, date_day
    from {{ ref(source) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    customer_id,
    conversion_action,
    array_agg(conversion_action_name order by date_day desc limit 1)[safe_offset(0)] as conversion_action_name,
    array_agg(conversion_action_category order by date_day desc limit 1)[safe_offset(0)] as conversion_action_category,
    min(date_day) as first_seen_date,
    max(date_day) as last_seen_date
from all_actions
where conversion_action is not null
group by customer_id, conversion_action
