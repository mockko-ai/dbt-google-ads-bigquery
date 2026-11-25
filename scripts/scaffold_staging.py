#!/usr/bin/env python3
"""Scaffold staging models from the data dictionary workbook.

    python scripts/scaffold_staging.py [--force]

Reads spec/google_ads_data_dictionary.xlsx and writes one
models/staging/stg_google_ads__<name>.sql per table whose Disposition is Build or
Stage only, plus models/staging/_google_ads__staging.yml.

The generator applies the staging rules mechanically (see README, "Rules"). Every
generated model was then reviewed and, where the rules cannot know better, corrected
through the override tables below (grain columns stored as attributes, resource-name ids,
curated column lists). Keeping the overrides in this file means a re-run reproduces
the reviewed models. Existing files are not overwritten unless --force is given.

Requires: openpyxl.
"""
import argparse
import collections
import os
import re
import sys

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKBOOK = os.path.join(ROOT, "spec", "google_ads_data_dictionary.xlsx")
OUT_DIR = os.path.join(ROOT, "models", "staging")

DATE_PARTS = {"segments_day_of_week", "segments_month", "segments_quarter", "segments_week", "segments_year"}

# --------------------------------------------------------------------------------------
# Feature-flag family for every source table (core families are on by default).
# --------------------------------------------------------------------------------------
FAMILY_PREFIXES = [
    # (regex on report name, flags that must all be on)
    (r"^Customer$|^AccountBasicStats$", ["account"]),
    (r"^AccountConversionStats$", ["account", "conversions"]),
    (r"^Campaign$|^Budget$|^CampaignLabel$|^CampaignBasicStats$", ["campaign"]),
    (r"^CampaignConversionStats$", ["campaign", "conversions"]),
    (r"^AdGroup$|^AdGroupLabel$|^AdGroupBasicStats$", ["ad_group"]),
    (r"^AdGroupConversionStats$", ["ad_group", "conversions"]),
    (r"^Ad$|^AdGroupAdLabel$|^AdBasicStats$", ["ad"]),
    (r"^AdConversionStats$", ["ad", "conversions"]),
    (r"^Keyword$|^KeywordBasicStats$", ["keyword"]),
    (r"^KeywordConversionStats$", ["keyword", "conversions"]),
    (r"^SearchQueryStats$", ["search_terms"]),
    (r"^SearchQueryConversionStats$", ["search_terms", "conversions"]),
    (r"^Hourly", ["hourly"]),
    (r"^AccountNonClickStats$", ["impression_share"]),
    (r"^(AgeRange|Gender|ParentalStatus)", ["demographics"]),
    (r"^(Audience|AdGroupAudience|CampaignAudience)", ["audiences"]),
    (r"^Placement", ["placements"]),
    (r"^Video", ["video"]),
    (r"^(Geo|CampaignLocationTargetStats|LocationBasedCampaignCriterion)", ["geo"]),
    (r"^(ShoppingProduct|ProductGroupStats)", ["shopping"]),
    (r"^(Asset|CampaignAssetStats)", ["pmax"]),
    (r"^(BidGoal|BudgetStats)", ["bidding_budget"]),
    (r"^(AdGroupCriterion|AdGroupBidModifier|CampaignCriterion|ClickStats|PaidOrganicStats)", ["criteria"]),
]


def families_for(report):
    for pattern, flags in FAMILY_PREFIXES:
        if re.search(pattern, report):
            return flags
    raise SystemExit(f"No feature-flag family for {report}")


# --------------------------------------------------------------------------------------
# Overrides, applied after the mechanical rules.
# --------------------------------------------------------------------------------------
# ads_Ad: keep a curated subset (about 25 of 78 columns): ids, ad type, name, strength,
# status, approval status, URLs, responsive search ad assets and the expanded text ad
# fields that still appear in older accounts. Format-specific display/app/legacy columns drop.
AD_KEEP = [
    "ad_group_ad_ad_type", "ad_group_ad_ad_name", "ad_group_ad_ad_strength", "ad_group_ad_status",
    "ad_group_ad_policy_summary_approval_status", "ad_group_ad_ad_final_urls",
    "ad_group_ad_ad_final_mobile_urls", "ad_group_ad_ad_display_url",
    "ad_group_ad_ad_tracking_url_template", "ad_group_ad_ad_added_by_google_ads",
    "ad_group_ad_ad_device_preference",
    "ad_group_ad_ad_responsive_search_ad_headlines", "ad_group_ad_ad_responsive_search_ad_descriptions",
    "ad_group_ad_ad_responsive_search_ad_path1", "ad_group_ad_ad_responsive_search_ad_path2",
    "ad_group_ad_ad_expanded_text_ad_headline_part1", "ad_group_ad_ad_expanded_text_ad_headline_part2",
    "ad_group_ad_ad_expanded_text_ad_headline_part3", "ad_group_ad_ad_expanded_text_ad_description",
    "ad_group_ad_ad_expanded_text_ad_description2",
]

# Attribute columns that stay on a stats table because they are part of its grain or are
# needed to join it. (The generic rule drops attributes from stats tables.)
KEEP_ATTRS = {
    "ads_SearchQueryStats": {"search_term_view_search_term": "search_term"},
    "ads_SearchQueryConversionStats": {"search_term_view_search_term": "search_term"},
    "ads_PaidOrganicStats": {"paid_organic_search_term_view_search_term": "search_term"},
    "ads_GeoStats": {"geographic_view_location_type": "location_type"},
    "ads_GeoConversionStats": {"geographic_view_location_type": "location_type"},
    "ads_ProductGroupStats": {"ad_group_criterion_display_name": "listing_group_display_name"},
    "ads_AssetGroupProductGroupStats": {},
}

# Extra expressions (alias, sql) for tables that only carry resource names.
# google_ads_extract_id(col) reads the trailing id; google_ads_extract_id(col, n) the nth
# id of a composite name such as customers/1234567890/adGroupAds/111~222.
EXTRA_SELECT = {
    "ads_AssetGroup": [
        ("asset_group_id", "coalesce(safe_cast(asset_group_id as int64), {extract(asset_group_id)})"),
        ("campaign_id", "{extract(asset_group_campaign)}"),
    ],
    "ads_AssetGroupAsset": [
        ("asset_group_id", "{extract(asset_group_asset_asset_group)}"),
        ("asset_id", "{extract(asset_group_asset_asset)}"),
    ],
    "ads_AssetGroupSignal": [
        ("asset_group_id", "{extract(asset_group_signal_asset_group)}"),
        ("audience_id", "{extract(asset_group_signal_audience_audience)}"),
    ],
    "ads_AssetGroupProductGroupStats": [
        ("asset_group_id", "{extract(asset_group_product_group_view_asset_group)}"),
        ("asset_group_listing_group_filter_id", "{extract(asset_group_product_group_view_asset_group_listing_group_filter)}"),
    ],
    "ads_CampaignAssetStats": [
        ("campaign_id", "{extract(campaign_asset_campaign)}"),
        ("asset_id", "{extract(campaign_asset_asset)}"),
        ("asset_field_type", "campaign_asset_field_type"),
        ("asset_source", "campaign_asset_source"),
    ],
    "ads_AdGroupAdLabel": [
        ("ad_id", "{extract(ad_group_ad_label_ad_group_ad, 2)}"),
    ],
}

# Source columns the generic rules would keep but we do not want.
DROP = {
    "ads_Asset": {"segments_conversion_action"},
    "ads_AdGroupAdLabel": {"ad_group_ad_label_ad_group_ad"},
    "ads_AssetGroup": {"asset_group_id", "asset_group_campaign"},
    "ads_AssetGroupAsset": {"asset_group_asset_asset_group", "asset_group_asset_asset"},
    "ads_AssetGroupSignal": {"asset_group_signal_asset_group", "asset_group_signal_audience_audience"},
    "ads_AssetGroupProductGroupStats": set(),
    "ads_CampaignAssetStats": {"campaign_asset_asset", "campaign_asset_campaign",
                               "campaign_asset_field_type", "campaign_asset_source"},
}

# Staged-name overrides. The workbook suggests keyword_id for every
# ad_group_criterion_criterion_id; that is only right for keywords.
def rename(report, col, suggested):
    if suggested == "keyword_id" and "Keyword" not in report:
        return "criterion_id"
    if col == "campaign_criterion_criterion_id":
        return "criterion_id"
    return suggested


# AccountNonClickStats keeps its share ratios: they are the point of that model.
KEEP_RATIO_PATTERN = {"ads_AccountNonClickStats": re.compile(r"impression_share$")}

# Tables whose stats are not at a daily level in the source.
DESCRIPTIONS = {
    "attribute": "Latest snapshot (_DATA_DATE = _LATEST_DATE) of the {report} report from the Google Ads transfer, renamed and with micros converted to currency.",
    "stats": "One row per grain of the {report} report from the Google Ads transfer. Additive metrics only; micros are converted to currency; no joins, aggregation or ratios.",
}


def load():
    wb = openpyxl.load_workbook(WORKBOOK, read_only=True)
    t = list(wb["Tables"].iter_rows(values_only=True))
    tables = {r[0]: dict(zip(t[0], r)) for r in t[1:]}
    c = list(wb["Columns"].iter_rows(values_only=True))
    cols = collections.defaultdict(list)
    for r in c[1:]:
        cols[r[0]].append(dict(zip(c[0], r)))
    return tables, cols


def build_model(table, meta, columns):
    report = table[len("ads_"):]
    kind = meta["Kind"]
    is_attr = kind == "attribute"
    has_customer = any(c["Column"] == "customer_id" for c in columns)
    drop = DROP.get(table, set())
    keep_attrs = KEEP_ATTRS.get(table, {})
    ratio_re = KEEP_RATIO_PATTERN.get(table)
    out, seen = [], set()

    def add(expr, alias):
        if alias in seen:
            raise SystemExit(f"{table}: duplicate output column {alias}")
        seen.add(alias)
        out.append((expr, alias))

    for c in columns:
        name, role, additive = c["Column"], c["Role"], c["Additive"]
        staged = rename(report, name, c["Suggested staged name"])
        if name in drop or name in DATE_PARTS:
            continue
        if role == "system":
            continue
        if role == "key":
            pass
        elif role == "segment":
            if is_attr:
                continue
        elif role == "metric":
            if is_attr:
                continue
            keep = additive == "yes" or (ratio_re and ratio_re.search(name))
            if not keep:
                continue
        elif role == "attribute":
            if table == "ads_Ad":
                if name not in AD_KEEP:
                    continue
            elif not is_attr:
                if name not in keep_attrs:
                    continue
                staged = keep_attrs[name]
        else:
            raise SystemExit(f"{table}.{name}: unknown role {role}")
        if c["Transform"] and "1,000,000" in c["Transform"]:
            add(f"cast({name} as numeric) / 1000000", staged)
        else:
            add(name, staged)

    front = []
    for alias, expr in EXTRA_SELECT.get(table, []):
        expr = re.sub(r"\{extract\(([^,)]+)(?:, *(\d+))?\)\}",
                      lambda m: "{{ google_ads_extract_id('%s'%s) }}" % (m.group(1), (", %s" % m.group(2)) if m.group(2) else ""),
                      expr)
        add(expr, alias)
        if alias.endswith("_id"):
            front.append(alias)

    if not has_customer:
        add("customer_id", "customer_id")  # derived by google_ads_source
        front.insert(0, "customer_id")
    # ids that come from resource names are keys: list them first
    out = [o for a in front for o in out if o[1] == a] + [o for o in out if o[1] not in front]
    if not is_attr:
        add("_DATA_DATE", "data_date")
    return report, is_attr, has_customer, out


def render(table, meta, columns):
    report, is_attr, has_customer, out = build_model(table, meta, columns)
    flags = ", ".join(f"'{f}'" for f in families_for(report))
    derive = "" if has_customer else ", derive_customer_id=true"
    width = max(len(a) for _, a in out)
    lines = []
    for i, (expr, alias) in enumerate(out):
        sep = "," if i < len(out) - 1 else ""
        if expr == alias:
            lines.append(f"        {expr}{sep}")
        else:
            lines.append(f"        {expr} as {alias}{sep}")
    where = "\n    where _DATA_DATE = _LATEST_DATE" if is_attr else ""
    sql = f"""{{{{ config(enabled=google_ads_enabled({flags})) }}}}

{{# {meta['Staging model']}: generated by scripts/scaffold_staging.py from {table}, then reviewed by hand. #}}

with source as (

    select * from {{{{ google_ads_source('{report}'{derive}) }}}}{where}

),

renamed as (

    select
{chr(10).join(lines)}
    from source

)

select * from renamed
"""
    return sql


def render_yaml(entries):
    lines = ["version: 2", "", "models:"]
    for name, desc, grain in entries:
        lines += [f"  - name: {name}", f"    description: >", f"      {desc}", f"      Grain: {grain}."]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="overwrite existing models")
    args = ap.parse_args()
    tables, cols = load()
    os.makedirs(OUT_DIR, exist_ok=True)
    entries, written, skipped = [], 0, 0
    for table, meta in tables.items():
        if meta["Disposition"] not in ("Build", "Stage only"):
            continue
        model = meta["Staging model"]
        path = os.path.join(OUT_DIR, f"{model}.sql")
        if os.path.exists(path) and not args.force:
            skipped += 1
        else:
            with open(path, "w") as f:
                f.write(render(table, meta, cols[table]))
            written += 1
        report = table[len("ads_"):]
        grain = meta["Grain (keys + segments)"] or "see data dictionary"
        entries.append((model, DESCRIPTIONS["attribute" if meta["Kind"] == "attribute" else "stats"].format(report=report), grain))
    with open(os.path.join(OUT_DIR, "_google_ads__staging.yml"), "w") as f:
        f.write(render_yaml(sorted(entries)))
    print(f"models written: {written}, existing kept: {skipped}, total: {written + skipped}")


if __name__ == "__main__":
    sys.exit(main())
