{#-
  Helpers for the conversion action reporting tables.

  var('google_ads_pivot_conversion_actions') is a list of conversion action names, for example
  ['Purchase', 'Signup']. When it is empty (the default) the rpt_google_ads__<grain>_conversion_daily
  models are switched off. When it is set, each of them is the matching rpt_google_ads__<grain>_daily
  model plus, per action: <slug>_conversions, <slug>_conversions_value, <slug>_cvr, <slug>_cpa and
  <slug>_roas. Rows stay one per entity and day, so every column stays additive.
-#}

{#- The configured action names, always as a list. -#}
{% macro google_ads_pivot_actions() -%}
  {%- set actions = var('google_ads_pivot_conversion_actions', []) -%}
  {%- if actions is none -%}
    {%- set actions = [] -%}
  {%- elif actions is string -%}
    {%- set actions = [actions] -%}
  {%- endif -%}
  {{ return(actions) }}
{%- endmacro %}

{#- Column-safe name for a conversion action: "Purchase (web)" -> purchase_web. -#}
{% macro google_ads_conversion_action_slug(name) -%}
  {%- set slug = modules.re.sub('[^a-z0-9]+', '_', (name | string | lower)) | trim('_') -%}
  {%- if slug == '' or slug[0] in '0123456789' -%}
    {%- set slug = 'action_' ~ slug -%}
  {%- endif -%}
  {{ return(slug) }}
{%- endmacro %}

{#- True when the grain's families are on and at least one action is configured. -#}
{% macro google_ads_pivot_enabled(grain) -%}
  {%- set families = {
      'account': ['account', 'conversions', 'reporting'],
      'campaign': ['account', 'campaign', 'conversions', 'reporting'],
      'ad_group': ['account', 'campaign', 'ad_group', 'conversions', 'reporting'],
      'ad': ['account', 'campaign', 'ad_group', 'ad', 'conversions', 'reporting'],
      'keyword': ['account', 'campaign', 'ad_group', 'keyword', 'conversions', 'reporting']
  } -%}
  {{ return(google_ads_pivot_actions() | length > 0 and google_ads_enabled(*families[grain])) }}
{%- endmacro %}

{#- Ratio columns shared by every rpt_google_ads__<grain>_daily model. `t` is the table alias. -#}
{% macro google_ads_ratio_metrics(t) -%}
    safe_divide({{ t }}.clicks, {{ t }}.impressions) as ctr,
    safe_divide({{ t }}.cost, {{ t }}.clicks) as cpc,
    safe_divide({{ t }}.cost, {{ t }}.impressions) * 1000 as cpm,
    safe_divide({{ t }}.cost, {{ t }}.conversions) as cpa,
    safe_divide({{ t }}.conversions_value, {{ t }}.cost) as roas,
    safe_divide({{ t }}.conversions, {{ t }}.clicks) as cvr
{%- endmacro %}

{#-
  google_ads_pivot_conversions(grain)

  grain: account | campaign | ad_group | ad | keyword
  Returns the select for rpt_google_ads__<grain>_conversion_daily.
-#}
{% macro google_ads_pivot_conversions(grain) -%}

  {%- set grains = {
      'account': {'keys': ['customer_id']},
      'campaign': {'keys': ['customer_id', 'campaign_id']},
      'ad_group': {'keys': ['customer_id', 'ad_group_id']},
      'ad': {'keys': ['customer_id', 'ad_group_id', 'ad_id']},
      'keyword': {'keys': ['customer_id', 'ad_group_id', 'keyword_id']}
  } -%}
  {%- if grain not in grains -%}
    {{ exceptions.raise_compiler_error("google_ads_pivot_conversions: unknown grain '" ~ grain ~ "'") }}
  {%- endif -%}

  {%- set keys = grains[grain]['keys'] -%}
  {%- set daily = ref('rpt_google_ads__' ~ grain ~ '_daily') -%}
  {%- set actions_model = ref('rpt_google_ads__' ~ grain ~ '_conversion_actions') -%}

  {%- set configured = google_ads_pivot_actions() -%}
  {%- set slugs = [] -%}
  {%- for action in configured -%}
    {%- set slug = google_ads_conversion_action_slug(action) -%}
    {%- if slug in slugs -%}
      {{ exceptions.raise_compiler_error(
        "google_ads_pivot_conversion_actions: '" ~ action ~ "' gives the column prefix '" ~ slug ~ "', which another action already uses."
      ) }}
    {%- endif -%}
    {%- do slugs.append(slug) -%}
  {%- endfor -%}

  {#- Warn (do not fail) about actions with no data, so the schema stays stable. -#}
  {%- if execute -%}
    {%- set existing = load_relation(actions_model) -%}
    {%- if existing is not none -%}
      {%- set found = run_query('select distinct lower(conversion_action_name) from ' ~ existing) -%}
      {%- set found_names = found.columns[0].values() -%}
      {%- for action in configured -%}
        {%- if (action | lower) not in found_names -%}
          {%- do exceptions.warn("google_ads_pivot_conversion_actions: no conversion action named '" ~ action ~ "' found for " ~ grain ~ "; its columns will be zero.") -%}
        {%- endif -%}
      {%- endfor -%}
    {%- endif -%}
  {%- endif -%}

with daily as (

    select * from {{ daily }}

),

conversions as (

    select
        {% for k in keys %}{{ k }},
        {% endfor %}date_day,
        {% for action in configured %}
        {%- set slug = slugs[loop.index0] -%}
        {%- set literal = (action | string | lower | replace('\\', '\\\\') | replace("'", "\\'")) -%}
        sum(if(lower(conversion_action_name) = '{{ literal }}', conversions, 0)) as {{ slug }}_conversions,
        sum(if(lower(conversion_action_name) = '{{ literal }}', conversions_value, 0)) as {{ slug }}_conversions_value{{ ',' if not loop.last }}
        {% endfor %}
    from {{ actions_model }}
    group by {% for k in keys %}{{ k }}, {% endfor %}date_day

)

select
    daily.*,
    {% for slug in slugs %}
    coalesce(conversions.{{ slug }}_conversions, 0) as {{ slug }}_conversions,
    coalesce(conversions.{{ slug }}_conversions_value, 0) as {{ slug }}_conversions_value,
    safe_divide(coalesce(conversions.{{ slug }}_conversions, 0), daily.clicks) as {{ slug }}_cvr,
    safe_divide(daily.cost, nullif(coalesce(conversions.{{ slug }}_conversions, 0), 0)) as {{ slug }}_cpa,
    safe_divide(coalesce(conversions.{{ slug }}_conversions_value, 0), daily.cost) as {{ slug }}_roas{{ ',' if not loop.last }}
    {% endfor %}
from daily
left join conversions
    on {% for k in keys %}daily.{{ k }} = conversions.{{ k }} and {% endfor %}daily.date_day = conversions.date_day

{%- endmacro %}
