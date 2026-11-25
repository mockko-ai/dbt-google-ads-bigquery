#!/usr/bin/env python3
"""Write tiny synthetic seed CSVs for the integration tests.

    python scripts/generate_seeds.py

Deterministic: no randomness, no clock. Everything is fake: customer id 1234567890,
fake campaign / ad group / ad ids, 28 days from 2025-01-01. Output goes to
integration_tests/seeds/ads_<Report>_1234567890.csv (the same names as the transfer's
source tables) plus integration_tests/seeds/_seeds.yml with the column types.

Columns come from spec/google_ads_data_dictionary.xlsx, so every column a staging model
reads exists in the seed; columns this script has no value for stay empty.

Data shape (so the tests have something to prove):
  * 2 campaigns, 2 ad groups each, 1 ad and 1 keyword per ad group. Ad and keyword ids repeat
    across ad groups on purpose (composite keys).
  * Basic stats at ad group, campaign and account level are sums of the same ad-group rows, so
    campaign cost reconciles to account cost and conversions reconcile to the conversion stats.
  * Two devices, one network, two slots (slot must be summed out by the facts).
  * Campaign 1 spikes on the last day (anomaly test). Two conversion actions.
  * Attribute tables carry an old snapshot with other names plus the latest snapshot
    (_DATA_DATE = _LATEST_DATE) to test that only the latest snapshot is used.
Requires: openpyxl.
"""
import csv
import datetime as dt
import os

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKBOOK = os.path.join(ROOT, "spec", "google_ads_data_dictionary.xlsx")
OUT = os.path.join(ROOT, "integration_tests", "seeds")

CUSTOMER = 1234567890
START = dt.date(2025, 1, 1)
DAYS = 28
LATEST = START + dt.timedelta(days=DAYS - 1)
OLD_SNAPSHOT = LATEST - dt.timedelta(days=1)
DEVICES = ["MOBILE", "DESKTOP"]
NETWORK = "SEARCH"
SLOTS = ["SEARCH_TOP", "SEARCH_OTHER"]
ACTIONS = [
    (f"customers/{CUSTOMER}/conversionActions/7001", "Purchase", "PURCHASE", 3, 5),
    (f"customers/{CUSTOMER}/conversionActions/7002", "Lead form", "SUBMIT_LEAD_FORM", 2, 5),
]  # (resource name, name, category, share numerator, share denominator)

CAMPAIGNS = [(101, "Brand search", 9001), (102, "Generic search", 9002)]
AD_GROUPS = [(1001, 101, "Brand exact"), (1002, 101, "Brand phrase"), (1003, 102, "Generic broad"), (1004, 102, "Generic phrase")]
AD_ID = 5001          # same ad id in every ad group
KEYWORD_ID = 6001     # same keyword id in every ad group
LABELS = {101: (801, "Priority"), 102: (802, "Test")}

# Source tables seeded: every table of the core families.
TABLES = [
    "Customer", "AccountBasicStats", "AccountConversionStats",
    "Campaign", "Budget", "CampaignLabel", "CampaignBasicStats", "CampaignConversionStats",
    "AdGroup", "AdGroupLabel", "AdGroupBasicStats", "AdGroupConversionStats",
    "Ad", "AdGroupAdLabel", "AdBasicStats", "AdConversionStats",
    "Keyword", "KeywordBasicStats", "KeywordConversionStats",
    "SearchQueryStats", "SearchQueryConversionStats",
]
TYPES = {"INT64": "int64", "FLOAT64": "float64", "STRING": "string", "BOOL": "boolean", "DATE": "date", "DATETIME": "datetime"}


def days():
    return [START + dt.timedelta(days=i) for i in range(DAYS)]


def base_metrics(ad_group_id, day, device, slot):
    """Additive metrics of one ad group / day / device / slot. Exact in binary floating point."""
    g = ad_group_id - 1000
    d = (day - START).days
    v = DEVICES.index(device)
    s = SLOTS.index(slot)
    impressions = 100 + 7 * g + 3 * d + 10 * v + 5 * s
    clicks = impressions // 10
    cost_micros = clicks * (500_000 + 50_000 * g)
    campaign_id = [c for a, c, _ in AD_GROUPS if a == ad_group_id][0]
    if campaign_id == 101 and day == LATEST:      # spike for the anomaly test
        cost_micros *= 10
        clicks *= 2
    quarters = clicks // 2
    return {
        "impressions": impressions, "clicks": clicks, "interactions": clicks,
        "cost_micros": cost_micros, "quarters": quarters,
    }


def conv_split(quarters):
    first = (quarters * ACTIONS[0][3]) // ACTIONS[0][4]
    return [first * 0.25, (quarters - first) * 0.25]


def sum_metrics(rows):
    out = {"impressions": 0, "clicks": 0, "interactions": 0, "cost_micros": 0, "quarters": 0}
    for r in rows:
        for k in out:
            out[k] += r[k]
    return out


def stats_values(m):
    conv = m["quarters"] * 0.25
    return {
        "metrics_impressions": m["impressions"], "metrics_clicks": m["clicks"],
        "metrics_interactions": m["interactions"], "metrics_cost_micros": m["cost_micros"],
        "metrics_conversions": conv, "metrics_conversions_value": conv * 40.0,
        "metrics_view_through_conversions": 0,
    }


def ad_group_rows():
    """(ad_group_id, day, device, slot) -> metrics"""
    return [
        (a, c, day, dev, slot, base_metrics(a, day, dev, slot))
        for a, c, _ in AD_GROUPS for day in days() for dev in DEVICES for slot in SLOTS
    ]


def build():
    rows = {t: [] for t in TABLES}
    base = ad_group_rows()
    stamp = lambda d: {"_DATA_DATE": d.isoformat(), "_LATEST_DATE": LATEST.isoformat()}

    # --- attribute tables: an old snapshot with other names, then the latest snapshot
    for snap, suffix in ((OLD_SNAPSHOT, " (old)"), (LATEST, "")):
        s = stamp(snap)
        rows["Customer"].append({"customer_id": CUSTOMER, "customer_descriptive_name": "Example account" + suffix,
                                 "customer_currency_code": "USD", "customer_time_zone": "America/New_York",
                                 "customer_manager": False, "customer_test_account": True,
                                 "customer_auto_tagging_enabled": True, **s})
        for cid, name, budget_id in CAMPAIGNS:
            rows["Campaign"].append({"campaign_id": cid, "customer_id": CUSTOMER, "campaign_name": name + suffix,
                                     "campaign_status": "ENABLED", "campaign_serving_status": "SERVING",
                                     "campaign_advertising_channel_type": "SEARCH",
                                     "campaign_bidding_strategy_type": "MAXIMIZE_CONVERSIONS",
                                     "campaign_campaign_budget": f"customers/{CUSTOMER}/campaignBudgets/{budget_id}",
                                     "campaign_budget_amount_micros": 50_000_000, "campaign_budget_period": "DAILY",
                                     "campaign_start_date_time": "2024-12-01T00:00:00", **s})
            rows["Budget"].append({"campaign_budget_id": budget_id, "customer_id": CUSTOMER,
                                   "campaign_budget_name": f"Budget {budget_id}" + suffix,
                                   "campaign_budget_amount_micros": 60_000_000, "campaign_budget_period": "DAILY",
                                   "campaign_budget_delivery_method": "STANDARD", "campaign_budget_explicitly_shared": False, **s})
            lid, lname = LABELS[cid]
            rows["CampaignLabel"].append({"campaign_id": cid, "label_id": lid, "campaign_name": name, "label_name": lname + suffix, **s})
        for a, c, name in AD_GROUPS:
            rows["AdGroup"].append({"ad_group_id": a, "campaign_id": c, "customer_id": CUSTOMER, "ad_group_name": name + suffix,
                                    "ad_group_status": "ENABLED", "ad_group_type": "SEARCH_STANDARD",
                                    "ad_group_cpc_bid_micros": 1_000_000, **s})
            rows["AdGroupLabel"].append({"ad_group_id": a, "label_id": LABELS[c][0], "ad_group_name": name, "label_name": LABELS[c][1] + suffix, **s})
            rows["Ad"].append({"ad_group_ad_ad_id": AD_ID, "ad_group_id": a, "campaign_id": c, "customer_id": CUSTOMER,
                               "ad_group_ad_ad_type": "RESPONSIVE_SEARCH_AD", "ad_group_ad_ad_name": f"Ad {a}" + suffix,
                               "ad_group_ad_status": "ENABLED", "ad_group_ad_ad_strength": "GOOD",
                               "ad_group_ad_policy_summary_approval_status": "APPROVED",
                               "ad_group_ad_ad_final_urls": '["https://www.example.com/"]', **s})
            rows["AdGroupAdLabel"].append({"ad_group_id": a, "label_id": LABELS[c][0],
                                           "ad_group_ad_label_ad_group_ad": f"customers/{CUSTOMER}/adGroupAds/{a}~{AD_ID}",
                                           "label_name": LABELS[c][1] + suffix, **s})
            rows["Keyword"].append({"ad_group_criterion_criterion_id": KEYWORD_ID, "ad_group_id": a, "campaign_id": c,
                                    "customer_id": CUSTOMER, "ad_group_criterion_keyword_text": f"example widget {a}" + suffix,
                                    "ad_group_criterion_keyword_match_type": "EXACT", "ad_group_criterion_negative": False,
                                    "ad_group_criterion_status": "ENABLED",
                                    "ad_group_criterion_quality_info_quality_score": 7, **s})

    # --- basic stats (ad group rows are the only source; higher levels are sums of them)
    def group(keyfn):
        out = {}
        for a, c, day, dev, slot, m in base:
            out.setdefault(keyfn(a, c, day, dev, slot), []).append(m)
        return out

    for (day, dev, slot), ms in sorted(group(lambda a, c, day, dev, slot: (day, dev, slot)).items()):
        rows["AccountBasicStats"].append({"customer_id": CUSTOMER, "segments_date": day.isoformat(), "segments_device": dev,
                                          "segments_ad_network_type": NETWORK, "segments_slot": slot,
                                          **stats_values(sum_metrics(ms)), **stamp(day)})
    for (c, day, dev, slot), ms in sorted(group(lambda a, c, day, dev, slot: (c, day, dev, slot)).items()):
        rows["CampaignBasicStats"].append({"campaign_id": c, "customer_id": CUSTOMER, "segments_date": day.isoformat(),
                                           "segments_device": dev, "segments_ad_network_type": NETWORK, "segments_slot": slot,
                                           **stats_values(sum_metrics(ms)), **stamp(day)})
    for a, c, day, dev, slot, m in base:
        common = {"ad_group_id": a, "campaign_id": c, "customer_id": CUSTOMER, "segments_date": day.isoformat(),
                  "segments_device": dev, "segments_ad_network_type": NETWORK, "segments_slot": slot,
                  **stats_values(m), **stamp(day)}
        rows["AdGroupBasicStats"].append(dict(common))
        rows["AdBasicStats"].append({**common, "ad_group_ad_ad_id": AD_ID})
        rows["KeywordBasicStats"].append({**common, "ad_group_criterion_criterion_id": KEYWORD_ID})

    # --- conversion stats: the same conversions split over two actions (and summed over slots in the facts)
    def conv_rows(table, extra_fn, aggregate):
        groups = aggregate
        for key, ms in sorted(groups.items(), key=lambda kv: str(kv[0])):
            q = sum_metrics(ms)["quarters"]
            for (res, name, cat, _, _), conv in zip(ACTIONS, conv_split(q)):
                rows[table].append({**extra_fn(key), "segments_conversion_action": res,
                                    "segments_conversion_action_name": name, "segments_conversion_action_category": cat,
                                    "metrics_conversions": conv, "metrics_conversions_value": conv * 40.0})

    conv_rows("AccountConversionStats",
              lambda k: {"customer_id": CUSTOMER, "segments_date": k[0].isoformat(), "segments_device": k[1],
                         "segments_slot": k[2], "segments_ad_network_type": NETWORK, "segments_click_type": "URL_CLICKS",
                         **stamp(k[0])},
              group(lambda a, c, day, dev, slot: (day, dev, slot)))
    conv_rows("CampaignConversionStats",
              lambda k: {"campaign_id": k[0], "customer_id": CUSTOMER, "segments_date": k[1].isoformat(),
                         "segments_slot": k[3], "segments_ad_network_type": NETWORK,
                         "segments_conversion_attribution_event_type": "CLICK_THROUGH", **stamp(k[1])},
              group(lambda a, c, day, dev, slot: (c, day, dev, slot)))
    ag = group(lambda a, c, day, dev, slot: (a, c, day, dev, slot))
    base_cols = lambda k: {"ad_group_id": k[0], "campaign_id": k[1], "customer_id": CUSTOMER, "segments_date": k[2].isoformat(),
                           "segments_device": k[3], "segments_slot": k[4], "segments_ad_network_type": NETWORK,
                           "segments_click_type": "URL_CLICKS", **stamp(k[2])}
    conv_rows("AdGroupConversionStats", base_cols, ag)
    conv_rows("AdConversionStats", lambda k: {**base_cols(k), "ad_group_ad_ad_id": AD_ID}, ag)
    conv_rows("KeywordConversionStats", lambda k: {**base_cols(k), "ad_group_criterion_criterion_id": KEYWORD_ID}, ag)

    # --- search terms: two terms per ad group and day (one converts, one only spends)
    terms = [("example widget", 4, 1.0), ("free widget", 3, 0.0)]
    for a, c, _ in AD_GROUPS:
        for day in days():
            for dev in DEVICES:
                for term, clicks, conv in terms:
                    k = {"ad_group_ad_ad_id": AD_ID, "ad_group_id": a, "campaign_id": c, "customer_id": CUSTOMER,
                         "segments_date": day.isoformat(), "segments_device": dev, "segments_ad_network_type": NETWORK,
                         "segments_keyword_ad_group_criterion": f"customers/{CUSTOMER}/adGroupCriteria/{a}~{KEYWORD_ID}",
                         "segments_search_term_match_type": "EXACT", "search_term_view_search_term": term, **stamp(day)}
                    rows["SearchQueryStats"].append({**k, "metrics_impressions": clicks * 10, "metrics_clicks": clicks,
                                                     "metrics_interactions": clicks, "metrics_cost_micros": clicks * 400_000,
                                                     "metrics_conversions": conv, "metrics_conversions_value": conv * 40.0,
                                                     "metrics_all_conversions": conv, "metrics_all_conversions_value": conv * 40.0,
                                                     "metrics_view_through_conversions": 0})
                    if conv:
                        rows["SearchQueryConversionStats"].append({**k, "segments_conversion_action": ACTIONS[0][0],
                                                                   "segments_conversion_action_name": ACTIONS[0][1],
                                                                   "segments_conversion_action_category": ACTIONS[0][2],
                                                                   "metrics_conversions": conv, "metrics_conversions_value": conv * 40.0,
                                                                   "metrics_all_conversions": conv, "metrics_all_conversions_value": conv * 40.0,
                                                                   "metrics_view_through_conversions": 0})
    return rows


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    return str(v)


def main():
    os.makedirs(OUT, exist_ok=True)
    wb = openpyxl.load_workbook(WORKBOOK, read_only=True)
    cols = {}
    for r in list(wb["Columns"].iter_rows(values_only=True))[1:]:
        cols.setdefault(r[0], []).append((r[2], r[3]))
    rows = build()
    yml = ["version: 2", "", "# Generated by scripts/generate_seeds.py. Do not edit.", "", "seeds:"]
    for report in TABLES:
        table = f"ads_{report}"
        name = f"{table}_{CUSTOMER}"
        header = [c for c, _ in cols[table]]
        for row in rows[report]:
            unknown = set(row) - set(header)
            if unknown:
                raise SystemExit(f"{table}: seed values for unknown columns {sorted(unknown)}")
        with open(os.path.join(OUT, f"{name}.csv"), "w", newline="") as f:
            w = csv.writer(f, lineterminator="\n")
            w.writerow(header)
            for row in rows[report]:
                w.writerow([fmt(row.get(c)) for c in header])
        yml += [f"  - name: {name}", "    config:", "      column_types:"]
        yml += [f"        {c}: {TYPES[t]}" for c, t in cols[table]]
    with open(os.path.join(OUT, "_seeds.yml"), "w") as f:
        f.write("\n".join(yml) + "\n")
    print(f"wrote {len(TABLES)} seeds, {sum(len(v) for v in rows.values())} rows")


if __name__ == "__main__":
    main()
