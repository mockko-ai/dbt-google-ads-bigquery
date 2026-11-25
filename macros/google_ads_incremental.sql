{#- Incremental window shared by every fact. -#}

{% macro google_ads_lookback_days() -%}
  {{ var('google_ads_lookback_days', 7) | int }}
{%- endmacro %}

{#- Predicate for the source side of an incremental fact: the last N days when
    running incrementally, everything on a full refresh. -#}
{% macro google_ads_incremental_predicate(date_column='date_day') -%}
  {%- if is_incremental() -%}
    {{ date_column }} >= date_sub(current_date(), interval {{ google_ads_lookback_days() }} day)
  {%- else -%}
    true
  {%- endif -%}
{%- endmacro %}

{#- Standard config for facts: incremental, insert_overwrite on the date partition,
    clustered on the main ids. `families` are the feature flags the fact depends on. -#}
{% macro google_ads_fact_config(families, cluster_by=[]) -%}
  {{ config(
      enabled=google_ads_enabled(*families),
      materialized='incremental',
      incremental_strategy='insert_overwrite',
      partition_by={'field': 'date_day', 'data_type': 'date', 'granularity': 'day'},
      cluster_by=cluster_by,
      on_schema_change='append_new_columns'
  ) }}
{%- endmacro %}
