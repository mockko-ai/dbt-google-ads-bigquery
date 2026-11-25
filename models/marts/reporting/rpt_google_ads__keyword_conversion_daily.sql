{{ config(enabled=google_ads_pivot_enabled('keyword')) }}

{#- rpt_google_ads__keyword_daily plus one set of columns per conversion action listed in
    var('google_ads_pivot_conversion_actions'). Off unless that list is set. See the macro. -#}

{{ google_ads_pivot_conversions('keyword') }}
