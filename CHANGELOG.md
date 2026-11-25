# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the package uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - unreleased

First release.

### Added

- Staging views for the 76 transfer tables the data dictionary marks Build or Stage only (`stg_google_ads__*`).
- 18 dimensions and bridges, 28 incremental facts, 12 ephemeral intermediate models.
- Reporting: weekly account, campaign, conversion action and search term rollups, `rpt_google_ads__anomalies`,
  `rpt_google_ads__narrative_context`.
- Macros `google_ads_source`, `google_ads_extract_id` and the feature flag and incremental helpers.
- Feature flags for every model family (`google_ads__using_<family>`).
- Tests: grain, keys, relationships, cost reconciliation, conversion consistency.
- `integration_tests/` project with deterministic synthetic seeds, and scripts to scaffold staging models, generate seeds and generate the model catalog.

### Needs verification

Grain, column roles and the additive flag were derived from column names, not verified against real data or Google's
documentation, and this release has not been run against a warehouse. Check these first. If a unique-grain test fails,
fix the model; do not loosen the test.

- `fct_google_ads__search_term_daily`, `fct_google_ads__search_term_conversion_daily`: grain includes the matched keyword
  resource name and match type; the search term column was added to the grain by hand.
- `fct_google_ads__geo_daily`, `fct_google_ads__geo_conversion_daily`: grain includes `location_type` (an attribute column in the source), the country criterion and the most specific location; `geo_target_id` is parsed from a resource name.
- `fct_google_ads__shopping_product_daily`, `fct_google_ads__shopping_product_conversion_daily`: about 30 product columns collapsed to item and merchant; brand and category use `max()`. The workbook lists no `metrics_conversions` column on the shopping conversion table, so that fact has `conversions_value` and `all_conversions` only.
- `fct_google_ads__audience_daily`, `fct_google_ads__audience_conversion_daily`, `dim_google_ads__audience_target`: the campaign level criterion id is a string in the source; ad group audience stats have no `campaign_id`; no audience name can be joined.
- `fct_google_ads__video_daily`: basic and non-click stats are assumed to share the grain ad, video, video channel, date, device, network.
- `fct_google_ads__campaign_asset_daily`, `dim_google_ads__asset`, `dim_google_ads__asset_group`, `bridge_google_ads__asset_group_asset`: ids are parsed from resource names and `customer_id` from the source table name; `asset_group_id` is a string key that may be a number or a resource name (both are handled).
- `dim_google_ads__campaign`: the budget join uses the id parsed from `campaign_campaign_budget`.
- `bridge_google_ads__*_label`, `stg_google_ads__*_label`: label tables have no `customer_id`; the ad label ad id is the second part of a composite resource name.
- `fct_google_ads__bidding_strategy_daily`, `fct_google_ads__budget_daily`: source grain has no network segment (bidding) and is budget plus campaign plus day (budget).
- `fct_google_ads__campaign_hourly`, `fct_google_ads__campaign_conversion_hourly`: hour and click type in the grain.
- `fct_google_ads__demographic_*`: parental status has no bid modifier column in the dictionary, so `bid_modifier` is null for it.
- Conversion consistency tests: conversions in basic stats and in conversion stats can legitimately differ (primary versus all actions, attribution settings). Tune `google_ads_conversion_tolerance` only after confirming why.
- `stg_google_ads__ad`: the curated column list (about 25 of 78) may need extending for formats you report on.
