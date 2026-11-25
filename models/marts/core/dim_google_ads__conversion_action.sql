{{ config(enabled=google_ads_enabled('conversions')) }}

{#- Derived: there is no conversion action table in the transfer.
    Key = the conversion action resource name (customers/<id>/conversionActions/<id>). -#}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'conversion_action']) }} as conversion_action_key,
    customer_id,
    conversion_action,
    {{ google_ads_extract_id('conversion_action') }} as conversion_action_id,
    conversion_action_name as name,
    conversion_action_category as category,
    first_seen_date,
    last_seen_date
from {{ ref('int_google_ads__conversion_actions') }}
