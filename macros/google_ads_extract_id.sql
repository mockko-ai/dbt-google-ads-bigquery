{#-
  google_ads_extract_id(resource_name_column, part=none)

  Some transfer tables (Performance Max, CampaignAssetStats, ...) carry only resource
  names such as 'customers/1234567890/campaigns/111'.

  part=none  -> the trailing number:
      safe_cast(regexp_extract(col, r'/(\d+)$') as int64)
  part=N     -> the Nth number of a composite resource name. Composite names join ids
      with '~' after the last slash, for example
        customers/1234567890/adGroupAds/111~222            (adGroupId~adId)
        customers/1234567890/assetGroupAssets/111~222~TYPE (assetGroupId~assetId~fieldType)
      so google_ads_extract_id(col, 1) = 111 and google_ads_extract_id(col, 2) = 222.
      A part that is missing or not numeric returns null.
-#}
{% macro google_ads_extract_id(resource_name_column, part=none) -%}
  {%- if part is none -%}
    safe_cast(regexp_extract({{ resource_name_column }}, r'/(\d+)$') as int64)
  {%- else -%}
    safe_cast(
      split(regexp_extract({{ resource_name_column }}, r'/([^/]+)$'), '~')[safe_offset({{ part | int - 1 }})]
      as int64
    )
  {%- endif -%}
{%- endmacro %}
