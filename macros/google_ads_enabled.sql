{#-
  google_ads_enabled('conversions', 'campaign')

  True only if every listed family is switched on. The flag for family X is
  var('google_ads__using_X'). Core families default to true, optional families to false.
  Every model passes this to config(enabled=...), staging models included, so that
  turning a family off removes its models (and their tests) from the project.
-#}
{% macro google_ads_enabled() -%}
  {%- set core = ['account', 'campaign', 'ad_group', 'ad', 'keyword', 'conversions', 'search_terms', 'reporting'] -%}
  {%- for family in varargs -%}
    {%- if not var('google_ads__using_' ~ family, family in core) -%}
      {{ return(false) }}
    {%- endif -%}
  {%- endfor -%}
  {{ return(true) }}
{%- endmacro %}
