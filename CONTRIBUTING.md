# Contributing

Thanks for helping. This package is generic and public: **never commit real customer ids, project or dataset names,
credentials or data.** Use `1234567890` and the synthetic seeds.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install dbt-bigquery openpyxl
export DBT_PROFILES_DIR=$PWD/ci           # dummy profile, reads env vars; no credentials needed to parse
dbt deps && dbt parse --vars '{google_ads_customer_ids: ["1234567890"]}'
cd integration_tests && dbt deps && dbt parse
```

## Rules for changes

- Follow the layering in the README: staging renames and casts only; facts additive only; ratios in the reporting layer.
- New model: add `enabled=google_ads_enabled(...)` for its feature flag(s), a YAML description, descriptions for every column of dims and facts, `unique_combination_of_columns` on the grain, `not_null` on keys and `relationships` to dims.
- Staging models are scaffolded by `scripts/scaffold_staging.py` from `spec/google_ads_data_dictionary.xlsx`. Put corrections in the script's override tables so a re-run reproduces them.
- Do not loosen a unique-grain test to make it pass. If it looks wrong, record the model in "Needs verification" in `CHANGELOG.md`.
- After changing the workbook or models run `python scripts/generate_model_catalog.py` and `python scripts/generate_seeds.py` and commit the results; CI checks they are current.
- Check that parsing works with the flags on, off and default (see `.github/workflows/ci.yml`).

## Running against BigQuery

`dbt build` in `integration_tests/` needs a BigQuery project. Set `GOOGLE_ADS_DBT_PROJECT`, `GOOGLE_ADS_DBT_DATASET`,
`GOOGLE_ADS_DBT_AUTH_METHOD` (and `GOOGLE_ADS_DBT_KEYFILE` for a service account), then `dbt seed && dbt build`.
CI runs it only when a `GCP_SA_KEY` secret exists.

## Pull requests

Describe what changed and which commands you ran (`dbt parse` with which flags, `dbt build` or not).
Update `CHANGELOG.md`.
