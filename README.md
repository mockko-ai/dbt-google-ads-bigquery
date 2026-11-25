# google_ads_bigquery

An open source [dbt](https://www.getdbt.com/) package that models Google Ads data loaded into BigQuery by the
**BigQuery Data Transfer Service for Google Ads**. It turns the transfer's report tables into staging views,
dimensions, daily facts, weekly rollups, anomaly flags and a compact JSON context for narratives.

> **Status: 0.1.0, not yet run against a live warehouse.** The package parses, and every model passes a static
> BigQuery syntax check, but `dbt build` has not been run on real data. Grain and column roles were derived from
> column names in a data dictionary, not verified against Google's documentation. See [Known limitations](#known-limitations).

## What this package is, and is not

It is:

- A transformation layer for the transfer's `ads_<Report>_<customer_id>` tables.
- Built for multiple customer ids (it unions explicit table names; no wildcard tables).
- A set of additive daily facts plus reporting models that compute ratios correctly from summed numerators and denominators.
- A source of pre-computed, ranked context for a person or an LLM to write a narrative from. **The package never calls an LLM.**

It is not:

- A package for Fivetran, Airbyte or the Google Ads API. Supported source: **BigQuery Data Transfer Service only**.
- A package for other warehouses. BigQuery only.
- A tool that ships data, credentials or real customer ids.

> **Warning: do not install this package in the same project as Fivetran's Google Ads packages
> (`fivetran/google_ads`, `fivetran/ad_reporting`).** They share the `stg_google_ads__` and `google_ads__` naming
> and several model names with this package, so the two would collide.

## Install

Requires dbt Core `>=1.6.0,<3.0.0` with `dbt-bigquery`.

```yaml
# packages.yml
packages:
  - git: "https://github.com/mockko-ai/dbt-google-ads-bigquery.git"
    revision: v0.1.0
```

Then:

```bash
dbt deps
dbt build
```

The package depends on `dbt-labs/dbt_utils` (`>=1.1.0,<2.0.0`), which `dbt deps` installs.

## Configuration

Set these in your `dbt_project.yml`:

```yaml
vars:
  google_ads_bigquery:
    google_ads_customer_ids: ["1234567890"]   # required: customer ids as strings
    google_ads_schema: google_ads             # dataset the transfer writes to
    # google_ads_database: my-gcp-project     # defaults to target.database
```

### Required variable

| Variable | Description |
|---|---|
| `google_ads_customer_ids` | List of customer ids (strings, no dashes). One source relation is built per id: `ads_<Report>_<customer_id>`. With one id there is no union; with several, relations are unioned with `dbt_utils.union_relations`. **Required**: the package raises a clear error if it is missing. |

### Optional variables

| Variable | Default | Description |
|---|---|---|
| `google_ads_database` | `target.database` | Project that holds the transfer dataset. |
| `google_ads_schema` | `google_ads` | Dataset that holds the transfer tables. |
| `google_ads_lookback_days` | `7` | Facts are incremental; this many recent days are rebuilt on each run (the transfer re-delivers recent days). |
| `google_ads_anomaly_zscore` | `3` | Z-score beyond which `rpt_google_ads__anomalies` flags a metric. |
| `google_ads_conversion_tolerance` | `0.005` | Tolerance of the conversion consistency tests (0.5 percent). |
| `google_ads_date_spine_start` | `2018-01-01` | First day of `dim_google_ads__date`. |

### Feature flags

Models of a family are switched with `google_ads__using_<family>`. Every model of a family, staging models included,
carries `enabled=` for its flags, so turning a family off removes its models and tests without breaking parsing.
Optional families are **off** by default because the transfer only creates those tables when the feature is in use.
Optional families that need campaign or ad group dims (almost all of them) expect those core families to stay on.

| Flag | Default | Source tables | Models |
|---|---|---|---|
| `google_ads__using_account` | on | Customer, AccountBasicStats | `dim_google_ads__account`, `fct_google_ads__account_daily` |
| `google_ads__using_campaign` | on | Campaign, Budget, CampaignLabel, CampaignBasicStats | campaign dim, label bridge, `fct_google_ads__campaign_daily` |
| `google_ads__using_ad_group` | on | AdGroup, AdGroupLabel, AdGroupBasicStats | ad group dim, label bridge, `fct_google_ads__ad_group_daily` |
| `google_ads__using_ad` | on | Ad, AdGroupAdLabel, AdBasicStats | ad dim, label bridge, `fct_google_ads__ad_daily` |
| `google_ads__using_keyword` | on | Keyword, KeywordBasicStats | keyword dim, `fct_google_ads__keyword_daily` |
| `google_ads__using_conversions` | on | `*ConversionStats` of the core levels (AccountConversionStats is staged as a control total) | conversion action dim, conversion facts (needs the level's flag too) |
| `google_ads__using_search_terms` | on | SearchQueryStats, SearchQueryConversionStats | search term facts |
| `google_ads__using_reporting` | on | (built from the facts) | `agg_*` and `rpt_*` models |
| `google_ads__using_demographics` | off | AgeRange, Gender, ParentalStatus and their basic and conversion stats | demographic dim and facts |
| `google_ads__using_audiences` | off | Audience, AdGroupAudience, CampaignAudience and stats | audience target dim and facts |
| `google_ads__using_placements` | off | Placement and stats | placement dim and facts |
| `google_ads__using_video` | off | Video, VideoBasicStats, VideoNonClickStats, VideoConversionStats | video dim and `fct_google_ads__video_daily` |
| `google_ads__using_geo` | off | GeoStats, GeoConversionStats, CampaignLocationTargetStats, LocationBasedCampaignCriterion | geo facts, example geo lookup seed |
| `google_ads__using_shopping` | off | ShoppingProductStats, ShoppingProductConversionStats, ProductGroupStats | shopping product facts |
| `google_ads__using_pmax` | off | Asset, AssetGroup, AssetGroupAsset, AssetGroupSignal, AssetGroupListingGroupFilter, AssetGroupProductGroupStats, CampaignAssetStats | asset dims, bridge, `fct_google_ads__campaign_asset_daily` |
| `google_ads__using_bidding_budget` | off | BidGoal, BidGoalStats, BidGoalConversionStats, BudgetStats | bidding strategy dim, bidding strategy and budget facts |
| `google_ads__using_hourly` | off | the seven `Hourly*` tables | hourly campaign facts |
| `google_ads__using_impression_share` | off | AccountNonClickStats | `fct_google_ads__account_impression_share_daily` |
| `google_ads__using_criteria` | off | AdGroupCriterion, AdGroupCriterionLabel, AdGroupBidModifier, CampaignCriterion, ClickStats, PaidOrganicStats | staging views only |

## Model catalog

76 staging views, 12 ephemeral intermediate models, 18 dimensions and bridges, 28 facts, 6 reporting models.
The full list, with source tables and feature flags, is in [`docs/model_catalog.md`](docs/model_catalog.md)
(generated from the data dictionary by `scripts/generate_model_catalog.py`).

| Layer | Folder | Prefix | Materialization |
|---|---|---|---|
| Staging | `models/staging/` | `stg_google_ads__` | view |
| Intermediate | `models/intermediate/` | `int_google_ads__` | ephemeral |
| Core | `models/marts/core/` | `dim_google_ads__`, `bridge_google_ads__`, `fct_google_ads__` | dims and bridges: table; facts: incremental |
| Reporting | `models/marts/reporting/` | `agg_google_ads__`, `rpt_google_ads__` | table |

Reporting models:

- `agg_google_ads__account_weekly`, `agg_google_ads__campaign_weekly`, `agg_google_ads__conversion_action_weekly`,
  `agg_google_ads__search_term_weekly`: weeks start on Monday; ratios are `safe_divide` of summed numerators and denominators;
  week-over-week change; campaigns also get change against the trailing 4-week average and share of account cost.
- `rpt_google_ads__anomalies`: campaign-day cost, conversions and CPA against the trailing 28 days, flagged beyond `google_ads_anomaly_zscore`.
- `rpt_google_ads__narrative_context`: one row per customer and week with `payload_json` (see below).

### Fact grains

All facts are incremental (`insert_overwrite`, partitioned by `date_day`).

| Fact | Grain |
|---|---|
| `fct_google_ads__account_daily` | `customer_id`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__campaign_daily` | `customer_id`, `campaign_id`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__ad_group_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__ad_daily` | `ad_key`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__keyword_daily` | `keyword_key`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__campaign_conversion_daily` | `customer_id`, `campaign_id`, `date_day`, `conversion_action_key`, `conversion_attribution_event_type`, `ad_network_type` |
| `fct_google_ads__ad_group_conversion_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `date_day`, `conversion_action_key`, `device`, `click_type`, `ad_network_type` |
| `fct_google_ads__ad_conversion_daily` | `ad_key`, `date_day`, `conversion_action_key`, `device`, `click_type`, `ad_network_type` |
| `fct_google_ads__keyword_conversion_daily` | `keyword_key`, `date_day`, `conversion_action_key`, `device`, `click_type`, `ad_network_type` |
| `fct_google_ads__search_term_daily` | `ad_key`, `search_term`, `search_term_match_type`, `keyword_ad_group_criterion`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__search_term_conversion_daily` | `ad_key`, `search_term`, `search_term_match_type`, `keyword_ad_group_criterion`, `date_day`, `conversion_action_key`, `device`, `ad_network_type` |
| `fct_google_ads__demographic_daily` | `demographic_key`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__demographic_conversion_daily` | `demographic_key`, `date_day`, `conversion_action_key`, `click_type`, `device`, `ad_network_type` |
| `fct_google_ads__audience_daily` | `audience_target_key`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__audience_conversion_daily` | `audience_target_key`, `date_day`, `conversion_action_key`, `device`, `ad_network_type` |
| `fct_google_ads__placement_daily` | `placement_key`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__placement_conversion_daily` | `placement_key`, `date_day`, `conversion_action_key`, `click_type`, `device`, `ad_network_type` |
| `fct_google_ads__video_daily` | `video_key`, `ad_id`, `video_channel_id`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__geo_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `geographic_view_country_criterion_id`, `location_type`, `geo_target_most_specific_location`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__geo_conversion_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `geographic_view_country_criterion_id`, `location_type`, `geo_target_most_specific_location`, `date_day`, `conversion_action_key`, `device`, `ad_network_type` |
| `fct_google_ads__shopping_product_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `product_item_id`, `product_merchant_id`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__shopping_product_conversion_daily` | `customer_id`, `campaign_id`, `ad_group_id`, `product_item_id`, `product_merchant_id`, `date_day`, `conversion_action_key`, `click_type`, `device`, `ad_network_type` |
| `fct_google_ads__campaign_asset_daily` | `customer_id`, `campaign_id`, `asset_id`, `asset_field_type`, `asset_source`, `date_day`, `device`, `ad_network_type` |
| `fct_google_ads__bidding_strategy_daily` | `bidding_strategy_key`, `date_day`, `device` |
| `fct_google_ads__budget_daily` | `customer_id`, `campaign_budget_id`, `campaign_id`, `date_day` |
| `fct_google_ads__campaign_hourly` | `customer_id`, `campaign_id`, `date_day`, `hour`, `device`, `ad_network_type`, `click_type` |
| `fct_google_ads__campaign_conversion_hourly` | `customer_id`, `campaign_id`, `date_day`, `hour`, `conversion_action_key`, `device`, `ad_network_type`, `click_type` |
| `fct_google_ads__account_impression_share_daily` | `customer_id`, `date_day`, `ad_network_type` |

## The rules, in plain words

1. **Staging only renames and casts.** No joins, no aggregation, no ratios. `segments_date` becomes `date_day`, `*_micros` columns are divided by 1,000,000 and lose the suffix (`cost`), and `_DATA_DATE` is kept as `data_date` on stats tables. Date-part segments (`day_of_week`, `month`, `quarter`, `week`, `year`) are dropped.
2. **Attribute tables keep the latest snapshot only** (`_DATA_DATE = _LATEST_DATE`). A renamed campaign shows its new name on old days. Use a dbt snapshot if you need history.
3. **Stats staging keeps additive metrics only.** Ratios, rates and averages (CTR, CPC, CPA, impression share, ...) are dropped, because they cannot be summed. The one exception is `AccountNonClickStats`, which keeps its impression share and lost-share columns because they are the point of that model.
4. **Facts hold additive metrics only.** Ratios are computed in the reporting layer from summed numerators and denominators. The exception is `fct_google_ads__account_impression_share_daily`: Google reports impression share as a ratio, so it is passed through at source grain and must never be summed or averaged.
5. **`slot` is summed out** of the basic stats facts. Their grain is entity, `date_day`, `device`, `ad_network_type`.
6. **Never join a basic stats model to a conversion stats model before rolling the conversion model up to entity and day.** Conversion rows multiply by conversion action; a straight join repeats clicks and cost. See the `int_google_ads__*_conversions_entity_day` models.
7. **Ad and keyword ids repeat across ad groups.** Ads and keywords are keyed on `customer_id`, `ad_group_id` and the entity id with `dbt_utils.generate_surrogate_key` (`ad_key`, `keyword_key`).
8. **Families that share a shape are unioned** (demographics, audience levels, video basic plus non-click) into one model with a type or level column.
9. **Facts are incremental** with `insert_overwrite`, partitioned by `date_day`, clustered on the main ids and `on_schema_change='append_new_columns'`. The last `google_ads_lookback_days` days are rebuilt on every run. Use `--full-refresh` to rebuild everything.
10. **No wildcard tables.** Source relations are explicit, one per customer id, because a wildcard fails if the pattern also matches a view.
11. **Tables with only resource names** (Performance Max, CampaignAssetStats, labels) get their ids from the resource name with `google_ads_extract_id`. Composite names (`adGroupId~adId`) are handled with its `part` argument.
12. **`dim_google_ads__conversion_action` is derived.** The transfer has no conversion action table, so it is built from the distinct conversion action columns of the conversion stats models.

### Macros

- `google_ads_source(report_name, derive_customer_id=false)`: the `from` expression for a report across all customer ids.
- `google_ads_extract_id(resource_name_column, part=none)`: `safe_cast(regexp_extract(col, r'/(\d+)$') as int64)`; with `part=N`, the Nth id of a composite resource name (`customers/1/adGroupAds/222~333`: part 1 is 222, part 2 is 333).
- `google_ads_enabled('family', ...)`: true if every listed feature flag is on. Used in every model's `config(enabled=...)`.
- `google_ads_fact_config(families, cluster_by)`, `google_ads_incremental_predicate()`: the shared fact config and lookback filter.

## Narrative context for LLMs

`rpt_google_ads__narrative_context` has one row per customer and week. The reader (a person or an LLM) should never see raw stats tables or do arithmetic, and may only quote numbers in the payload. `payload_json` is built with `to_json_string(struct(...))` and contains:

- `period`, `currency_code`, `time_zone`, and `data_through_date` (never describe days after it);
- `totals`: for cost, clicks, impressions, conversions, conversions value, CTR, CPC, CPA, ROAS and conversion rate: `value`, `previous`, `change`, `change_pct` and `unit`;
- `top_campaign_movers`: top 5 up and down by cost and by conversions, with campaign names;
- `top_anomalies` (5), `top_conversion_actions` (5, with names and mix shift), `top_search_terms_without_conversions` (10);
- `definitions`: one line each for CTR, CPA, ROAS, change, movers, anomalies and so on.

Every list is ranked in SQL with a fixed sort (value, then id or name as tie-break) and a fixed cap, so the same data gives the same payload. `payload_hash` is the md5 of the payload: log it, together with the generated text, in a table outside dbt so that any sentence can be traced back to the numbers behind it.

## Tests

- Every model has a description; every column of dims and facts has one.
- Dims and facts have `dbt_utils.unique_combination_of_columns` on their grain and `not_null` on keys. Facts have `relationships` to their dims (severity `warn`, because the attribute snapshots can drop entities that still have old stats).
- `tests/assert_google_ads_campaign_cost_reconciles_to_account.sql`: summed campaign cost by day matches account cost within 0.5 percent.
- `tests/assert_google_ads_campaign_conversions_consistent.sql` and `..._ad_group_...`: conversions in the basic stats match the conversion stats summed to entity and day.
- `integration_tests/` is a separate dbt project that installs the package with `local: ../` and runs it on synthetic seeds (see its tests for macro unit tests and expected row counts).

## Known limitations

- Not yet validated on a live warehouse (see status above).
- Grain, roles and the additive flag come from column names. The "Needs verification" list in `CHANGELOG.md` names the models to check first.
- Weekly rollups compute the trailing 4-week average and the 28-day anomaly baseline over days or weeks that have rows; periods with no rows count as missing, not as zero.
- `dim_google_ads__ad` keeps only the responsive search ad columns (plus type, name, strength, status, approval and URLs). Other ad formats are in staging but not in the dim.
- The audience stats have no audience name, so `dim_google_ads__audience_target` has none.
- The geo lookup seed is an example with six countries; replace it with Google's full list if you need names.
- Time zone and currency are per account. Convert before summing across accounts with different currencies.
- Generic test arguments use the top-level style so the package works from dbt 1.6; dbt 1.10 and later print a deprecation warning that is safe to ignore for now.

## Upgrade notes

- **0.1.0**: first release. Nothing to upgrade from. Facts are incremental: after changing `google_ads_lookback_days` or upgrading across a release that adds columns, run `dbt run --full-refresh -s google_ads_bigquery` once if you need history rebuilt (new columns are appended with `append_new_columns`, but only populated for rebuilt days).

## Repository layout

```
dbt_project.yml, packages.yml     package config
macros/                           source, id extraction, feature flag and incremental macros
models/staging|intermediate|marts  the models
seeds/                            example geo target lookup
tests/                            singular tests (reconciliation, consistency)
integration_tests/                separate dbt project with synthetic seeds and its own tests
scripts/                          scaffold_staging.py, generate_seeds.py, generate_model_catalog.py
spec/                             the data dictionary the models were built from
docs/model_catalog.md             generated catalog
```

## License

Apache-2.0. See [LICENSE](LICENSE).
