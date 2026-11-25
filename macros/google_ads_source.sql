{#-
  google_ads_source(report_name, derive_customer_id=false)

  Returns a FROM-clause expression for one Google Ads transfer report, for example
  report_name='CampaignBasicStats' reads ads_CampaignBasicStats_<customer_id>.

  * One relation is built per customer id in var('google_ads_customer_ids') with
    api.Relation.create. Table names are always explicit; BigQuery wildcard tables
    are never used because a wildcard fails if the pattern also matches a view.
  * With one customer id the relation is returned as is (no union).
  * With several, the relations are unioned with dbt_utils.union_relations.
  * derive_customer_id=true is for the few report tables that have no
    customer_id column (the Performance Max tables, labels and so on). The customer id
    is then read from the source table name.
-#}
{% macro google_ads_source(report_name, derive_customer_id=false) -%}

  {%- set customer_ids = var('google_ads_customer_ids', none) -%}
  {%- if customer_ids is none or customer_ids is string or customer_ids | length == 0 -%}
    {{ exceptions.raise_compiler_error(
      "google_ads_bigquery: set var 'google_ads_customer_ids' to a list of customer id strings, e.g. ['1234567890']."
    ) }}
  {%- endif -%}

  {%- set database = var('google_ads_database', target.database) -%}
  {%- set schema = var('google_ads_schema', 'google_ads') -%}

  {%- set relations = [] -%}
  {%- for customer_id in customer_ids -%}
    {%- do relations.append(
      api.Relation.create(
        database=database,
        schema=schema,
        identifier='ads_' ~ report_name ~ '_' ~ (customer_id | string | trim),
        type='table'
      )
    ) -%}
  {%- endfor -%}

  {%- if relations | length == 1 -%}
    {%- if derive_customer_id -%}
      (select *, safe_cast('{{ customer_ids[0] | string | trim }}' as int64) as customer_id from {{ relations[0] }})
    {%- else -%}
      {{ relations[0] }}
    {%- endif -%}
  {%- else -%}
    {%- if derive_customer_id -%}
      (
        select
          *,
          safe_cast(regexp_extract(_dbt_source_relation, r'_(\d+)\W*$') as int64) as customer_id
        from (
          {{ dbt_utils.union_relations(relations=relations) }}
        )
      )
    {%- else -%}
      (
        {{ dbt_utils.union_relations(relations=relations) }}
      )
    {%- endif -%}
  {%- endif -%}

{%- endmacro %}
