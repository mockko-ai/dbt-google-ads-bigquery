{{ config(enabled=google_ads_enabled('account')) }}

select
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as account_key,
    customer_id,
    customer_descriptive_name as descriptive_name,
    customer_currency_code as currency_code,
    customer_time_zone as time_zone,
    customer_manager as is_manager,
    customer_test_account as is_test_account,
    customer_auto_tagging_enabled as is_auto_tagging_enabled
from {{ ref('stg_google_ads__customer') }}
