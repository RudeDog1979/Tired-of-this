#!/usr/bin/env python3
"""
Monthly global tax updater — prose + compute catalogs for all countries.

Publishes to the same GitHub Gist:
  - buxmuse_tax.json         (reference prose — Tax Profile UI)
  - buxmuse_tax_compute.json (structured math — Tax Engine)

Setup:
  export GIST_ID_TAX="d450143a13ad1df94f99f11c5ffef863"
  export GIST_TOKEN="github_pat_..."
  export GEMINI_API_KEY="..."

Run:
  python3 scripts/global_tax_updater.py
"""

import argparse
import os
import json
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BUNDLED_COMPUTE_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "BuxMuse", "Resources", "buxmuse_tax_compute.json")
)
PROGRESS_PATH = os.path.join(SCRIPT_DIR, ".tax_updater_progress.json")

# --- CONFIGURATION & ENV VARIABLES ---
GIST_ID = os.environ.get("GIST_ID_TAX", "d450143a13ad1df94f99f11c5ffef863")
GIST_PROSE_FILENAME = "buxmuse_tax.json"
GIST_COMPUTE_FILENAME = "buxmuse_tax_compute.json"
GIST_TOKEN = os.environ.get("GIST_TOKEN")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GEMINI_MODEL = "gemini-3.1-flash-lite"
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
)

REQUEST_SLEEP_SECONDS = 1.2

def _require_api_keys(*, needs_gemini: bool) -> None:
    if not GIST_TOKEN:
        raise SystemExit("System Error: Missing required GIST_TOKEN environment variable.")
    if needs_gemini and not GEMINI_API_KEY:
        raise SystemExit("System Error: Missing required GEMINI_API_KEY environment variable.")

# Live calculator modules in the iOS app today (coverageTier T1).
T1_COUNTRIES = frozenset({"GB", "US", "ES", "DO", "FR", "PL"})

# --- COUNTRY REGISTRY ---
MAJOR_COUNTRIES = [
    "US", "DO", "MX", "CA", "GB", "DE", "FR", "ES", "IT",
    "IN", "BR", "AR", "CL", "CO", "PE", "JP", "CN", "AU",
    "KR", "SG",
]

ALL_OTHER_COUNTRIES = [
    "AF", "AL", "DZ", "AD", "AO", "AI", "AQ", "AG", "AM", "AW", "AT", "AZ", "BS", "BH", "BD", "BB",
    "BY", "BE", "BZ", "BJ", "BM", "BT", "BO", "BA", "BW", "BV", "IO", "BN", "BG", "BF", "BI", "KH",
    "CM", "CV", "KY", "CF", "TD", "KM", "CG", "CD", "CK", "CR", "CI", "HR", "CU", "CY", "CZ", "DK",
    "DJ", "DM", "EC", "EG", "SV", "GQ", "ER", "EE", "ET", "FK", "FO", "FJ", "FI", "GF", "PF", "TF",
    "GA", "GM", "GE", "GH", "GI", "GL", "GD", "GP", "GU", "GT", "GG", "GN", "GW", "GY", "HT", "HM",
    "VA", "HN", "HK", "HU", "IS", "ID", "IR", "IQ", "IE", "IM", "IL", "JM", "JO", "KZ", "KE", "KI",
    "KP", "KW", "KG", "LA", "LV", "LB", "LS", "LR", "LY", "LI", "LT", "LU", "MO", "MK", "MG", "MW",
    "MY", "MV", "ML", "MT", "MH", "MQ", "MR", "MU", "YT", "FM", "MD", "MC", "MN", "ME", "MS", "MA",
    "MZ", "MM", "NA", "NR", "NP", "NL", "NC", "NZ", "NI", "NE", "NG", "NU", "NF", "MP", "NO", "OM",
    "PK", "PW", "PS", "PA", "PG", "PY", "PH", "PN", "PL", "PT", "PR", "QA", "RE", "RO", "RU", "RW",
    "BL", "SH", "KN", "LC", "MF", "PM", "VC", "WS", "SM", "ST", "SA", "SN", "RS", "SC", "SL", "SX",
    "SK", "SI", "SB", "SO", "ZA", "GS", "SS", "LK", "SD", "SR", "SJ", "SZ", "SE", "CH", "SY", "TW",
    "TJ", "TZ", "TH", "TL", "TG", "TK", "TO", "TT", "TN", "TR", "TM", "TC", "TV", "UG", "UA", "AE",
    "UM", "UY", "UZ", "VU", "VE", "VN", "VG", "VI", "WF", "EH", "YE", "ZM", "ZW",
]

ISO_COUNTRIES = MAJOR_COUNTRIES + [c for c in ALL_OTHER_COUNTRIES if c not in MAJOR_COUNTRIES]

PROSE_PROMPT = (
    "Provide the current tax, currency, geographic region, and specific "
    "self-employed/freelance tax bracket information for the country with ISO code: {code}"
)

COMPUTE_PROMPT = (
    "Provide current numeric self-employed tax computation rules for ISO country {code}. "
    "Use official currency amounts for bracket thresholds. "
    "Express all rates as decimals (e.g. 0.20 for 20%, not 20). "
    "Include VAT/GST standard rate as a decimal. "
    "If the country has important regional income tax variations (e.g. US states, UK nations), "
    "list them in regions and regionalOverrides. "
    "For US states, include salesTaxRate (state sales/use tax as decimal) on each regionalOverride. "
    "If data is uncertain or highly simplified, set coverageTier to T3 and use empty brackets."
)

# --- GEMINI SCHEMAS ---
PROSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "name": {"type": "STRING", "description": "The full name of the country."},
        "currency": {"type": "STRING", "description": "Standard 3-letter currency code (e.g. USD, EUR, DOP)."},
        "region": {"type": "STRING", "description": "The geographic region or continent."},
        "vat": {"type": "STRING", "description": "Standard VAT or GST rate details."},
        "income_tax": {"type": "STRING", "description": "General summary of personal income tax brackets."},
        "self_employed_tax": {"type": "STRING", "description": "Self-employed / freelancer tax rules."},
        "notes": {"type": "STRING", "description": "Regional variations and essential notes."},
    },
    "required": ["name", "currency", "region", "vat", "income_tax", "self_employed_tax", "notes"],
}

BRACKET_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "from": {"type": "NUMBER", "description": "Lower bound in local currency; 0 for first bracket."},
        "to": {"type": "NUMBER", "description": "Upper bound in local currency; omit for top bracket."},
        "rate": {"type": "NUMBER", "description": "Marginal rate as decimal (0.20 = 20%)."},
    },
    "required": ["from", "rate"],
}

SOCIAL_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "id": {"type": "STRING"},
        "labelKey": {"type": "STRING", "description": "Short English label for the contribution."},
        "rate": {"type": "NUMBER", "description": "Rate as decimal applied per rule semantics."},
        "profitRateMultiplier": {"type": "NUMBER"},
        "lowerProfitBound": {"type": "NUMBER"},
        "upperProfitBound": {"type": "NUMBER"},
        "annualCap": {"type": "NUMBER"},
    },
    "required": ["id", "labelKey", "rate"],
}

REGION_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "code": {"type": "STRING"},
        "name": {"type": "STRING"},
    },
    "required": ["code", "name"],
}

INCOME_RULES_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "personalAllowance": {"type": "NUMBER"},
        "brackets": {"type": "ARRAY", "items": BRACKET_SCHEMA},
        "socialContributions": {"type": "ARRAY", "items": SOCIAL_SCHEMA},
    },
    "required": ["brackets", "socialContributions"],
}

REGIONAL_OVERRIDE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "code": {"type": "STRING", "description": "Region code matching meta.regions (e.g. CA, SCT)."},
        "selfEmployed": INCOME_RULES_SCHEMA,
        "salesTaxRate": {
            "type": "NUMBER",
            "description": "US state sales/use tax rate as decimal (e.g. 0.0725). Omit if N/A.",
        },
    },
    "required": ["code", "selfEmployed"],
}

COMPUTE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "currency": {"type": "STRING", "description": "3-letter ISO currency code."},
        "taxYear": {"type": "STRING", "description": "Current tax year label, e.g. 2025 or 2025-26."},
        "fiscalYearStartMonth": {"type": "INTEGER", "description": "1-12"},
        "fiscalYearStartDay": {"type": "INTEGER", "description": "1-31"},
        "coverageTier": {
            "type": "STRING",
            "description": "T1 = verified module quality, T2 = structured estimate, T3 = reference only.",
            "enum": ["T1", "T2", "T3"],
        },
        "paymentSchedule": {
            "type": "STRING",
            "description": "Typical filing cadence: monthly, quarterly, or annual.",
            "enum": ["monthly", "quarterly", "annual"],
        },
        "selfEmployed": INCOME_RULES_SCHEMA,
        "employed": INCOME_RULES_SCHEMA,
        "vatStandardRate": {"type": "NUMBER", "description": "Standard VAT/GST rate as decimal."},
        "vatRegistrationThreshold": {"type": "NUMBER", "description": "Annual turnover threshold or 0 if N/A."},
        "vatFilingFrequency": {
            "type": "STRING",
            "enum": ["monthly", "quarterly", "annual"],
        },
        "advancePaymentRateOnGross": {
            "type": "NUMBER",
            "description": "Monthly advance on gross if applicable (e.g. DR 0.015), else omit.",
        },
        "advancePaymentLabel": {"type": "STRING"},
        "regions": {"type": "ARRAY", "items": REGION_SCHEMA},
        "regionalOverrides": {"type": "ARRAY", "items": REGIONAL_OVERRIDE_SCHEMA},
    },
    "required": [
        "currency", "taxYear", "fiscalYearStartMonth", "fiscalYearStartDay",
        "coverageTier", "paymentSchedule", "selfEmployed", "vatStandardRate",
    ],
}


# --- CORE API METHODS ---
def gemini_json_request(prompt, schema):
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": schema,
        },
    }
    req = urllib.request.Request(
        GEMINI_URL,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = json.loads(resp.read().decode())
        json_text = raw["candidates"][0]["content"]["parts"][0]["text"]
        return json.loads(json_text)


def gemini_prose_request(code):
    return gemini_json_request(PROSE_PROMPT.format(code=code), PROSE_SCHEMA)


def gemini_compute_request(code):
    return gemini_json_request(COMPUTE_PROMPT.format(code=code), COMPUTE_SCHEMA)


def normalize_prose(code, data):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return {
        "name": data.get("name", "N/A"),
        "isoCode": code,
        "currency": data.get("currency", "N/A"),
        "region": data.get("region", "N/A"),
        "vat": data.get("vat", "N/A"),
        "income_tax": data.get("income_tax", "N/A"),
        "self_employed_tax": data.get("self_employed_tax", "N/A"),
        "notes": data.get("notes", "N/A"),
        "lastVerified": today,
    }


def _clean_brackets(brackets):
    cleaned = []
    for bracket in brackets or []:
        entry = {"from": bracket["from"], "rate": bracket["rate"]}
        if bracket.get("to") is not None:
            entry["to"] = bracket["to"]
        cleaned.append(entry)
    return cleaned


def _clean_social(rules):
    cleaned = []
    for rule in rules or []:
        entry = {
            "id": rule["id"],
            "labelKey": rule["labelKey"],
            "rate": rule["rate"],
        }
        for key in ("profitRateMultiplier", "lowerProfitBound", "upperProfitBound", "annualCap"):
            if rule.get(key) is not None:
                entry[key] = rule[key]
        cleaned.append(entry)
    return cleaned


def _clean_income_rules(data):
    if not data:
        return None
    rules = {
        "brackets": _clean_brackets(data.get("brackets")),
        "socialContributions": _clean_social(data.get("socialContributions")),
    }
    if data.get("personalAllowance") is not None:
        rules["personalAllowance"] = data["personalAllowance"]
    return rules


def normalize_compute(code, data):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    tier = "T1" if code in T1_COUNTRIES else data.get("coverageTier", "T2")

    supported_paths = ["selfEmployed", "gig"]
    if code in T1_COUNTRIES:
        supported_paths.append("employedHypothetical")

    national = {}
    self_employed = _clean_income_rules(data.get("selfEmployed"))
    if self_employed:
        national["selfEmployed"] = self_employed

    employed = _clean_income_rules(data.get("employed"))
    if employed and code in T1_COUNTRIES:
        national["employed"] = employed

    vat_rate = data.get("vatStandardRate")
    if vat_rate is not None:
        vat = {"standardRate": vat_rate}
        if data.get("vatRegistrationThreshold") is not None:
            vat["registrationThreshold"] = data["vatRegistrationThreshold"]
        if data.get("vatFilingFrequency"):
            vat["filingFrequency"] = data["vatFilingFrequency"]
        national["vat"] = vat

    if data.get("paymentSchedule"):
        national["paymentSchedule"] = data["paymentSchedule"]

    advance_rate = data.get("advancePaymentRateOnGross")
    if advance_rate is not None and advance_rate > 0:
        national["advancePayments"] = [{
            "id": f"{code.lower()}-advance",
            "labelKey": data.get("advancePaymentLabel") or "Advance tax payment",
            "rateOnGross": advance_rate,
        }]

    meta = {
        "isoCode": code,
        "currency": data.get("currency", "XXX"),
        "taxYear": data.get("taxYear", str(datetime.now(timezone.utc).year)),
        "fiscalYearStartMonth": int(data.get("fiscalYearStartMonth", 1)),
        "fiscalYearStartDay": int(data.get("fiscalYearStartDay", 1)),
        "coverageTier": tier,
        "supportedIncomePaths": supported_paths,
        "lastVerified": today,
    }

    regions = data.get("regions") or []
    if regions:
        meta["regions"] = [
            {"code": r["code"], "name": r["name"]}
            for r in regions
            if r.get("code") and r.get("name")
        ]

    entry = {"meta": meta, "national": national}

    regional_overrides = {}
    for override in data.get("regionalOverrides") or []:
        region_code = (override.get("code") or "").upper()
        region_rules = _clean_income_rules(override.get("selfEmployed"))
        if region_code and region_rules:
            regional_block = {"selfEmployed": region_rules}
            sales_tax = override.get("salesTaxRate")
            if sales_tax is not None and sales_tax > 0:
                regional_block["salesTaxRate"] = sales_tax
            regional_overrides[region_code] = regional_block

    if regional_overrides:
        entry["regionalOverrides"] = regional_overrides

    return entry


def update_gist(prose_countries, compute_countries):
    """Pushes prose + compute catalogs to GitHub Gist in one PATCH."""
    updated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    prose_wrapped = {
        "version": 1,
        "updatedAt": updated_at,
        "countries": prose_countries,
    }
    compute_wrapped = {
        "schemaVersion": 1,
        "updatedAt": updated_at,
        "countries": compute_countries,
    }

    url = f"https://api.github.com/gists/{GIST_ID}"
    payload = {
        "files": {
            GIST_PROSE_FILENAME: {
                "content": json.dumps(prose_wrapped, indent=2, ensure_ascii=False),
            },
            GIST_COMPUTE_FILENAME: {
                "content": json.dumps(compute_wrapped, indent=2, ensure_ascii=False),
            },
        }
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {GIST_TOKEN}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
        method="PATCH",
    )

    with urllib.request.urlopen(req, timeout=120) as resp:
        if resp.status == 200:
            print("🚀 Success: buxmuse_tax.json + buxmuse_tax_compute.json pushed to Gist.")
        else:
            print(f"⚠️ Gist update returned HTTP response code: {resp.status}")


# --- GIST / PROGRESS HELPERS (Phase G) ---
def fetch_gist_catalogs():
    """Load existing prose + compute maps from the gist (for resume / merge)."""
    url = f"https://api.github.com/gists/{GIST_ID}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {GIST_TOKEN}",
            "Accept": "application/vnd.github+json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        print(f"⚠️ Could not read gist ({exc.code}); starting fresh.")
        return {}, {}

    files = payload.get("files", {})
    prose = {}
    compute = {}

    prose_raw = files.get(GIST_PROSE_FILENAME, {}).get("content")
    if prose_raw:
        try:
            prose = json.loads(prose_raw).get("countries", {})
        except json.JSONDecodeError:
            print("⚠️ Existing prose gist JSON invalid; ignoring.")

    compute_raw = files.get(GIST_COMPUTE_FILENAME, {}).get("content")
    if compute_raw:
        try:
            compute = json.loads(compute_raw).get("countries", {})
        except json.JSONDecodeError:
            print("⚠️ Existing compute gist JSON invalid; ignoring.")

    return prose, compute


def load_progress():
    if not os.path.exists(PROGRESS_PATH):
        return {"done": [], "prose": {}, "compute": {}}
    with open(PROGRESS_PATH, "r", encoding="utf-8") as handle:
        return json.load(handle)


def save_progress(progress):
    with open(PROGRESS_PATH, "w", encoding="utf-8") as handle:
        json.dump(progress, handle, indent=2, ensure_ascii=False)


def load_bundled_t1_pins():
    """Preserve hand-verified T1 blocks from the iOS bundle."""
    if not os.path.exists(BUNDLED_COMPUTE_PATH):
        print(f"⚠️ Bundled compute not found at {BUNDLED_COMPUTE_PATH}")
        return {}
    with open(BUNDLED_COMPUTE_PATH, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    countries = payload.get("countries", {})
    return {
        code: countries[code]
        for code in T1_COUNTRIES
        if code in countries
    }


def merge_t1_pins(compute_records):
    pins = load_bundled_t1_pins()
    if not pins:
        return compute_records
    merged = dict(compute_records)
    for code, entry in pins.items():
        merged[code] = entry
        print(f"📌 Pinned bundled T1 compute for {code}")
    return merged


def write_local_compute(compute_records):
    updated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload = {
        "schemaVersion": 1,
        "updatedAt": updated_at,
        "countries": compute_records,
    }
    os.makedirs(os.path.dirname(BUNDLED_COMPUTE_PATH), exist_ok=True)
    with open(BUNDLED_COMPUTE_PATH, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"💾 Wrote local bundle: {BUNDLED_COMPUTE_PATH}")


def parse_args():
    parser = argparse.ArgumentParser(description="Monthly BuxMuse tax catalog updater")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Skip ISO codes already in progress file or existing gist",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Process at most N new countries (0 = all)",
    )
    parser.add_argument(
        "--codes",
        nargs="*",
        help="Only refresh these ISO codes (e.g. --codes DE FR IT)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="No Gemini calls and no gist push",
    )
    parser.add_argument(
        "--skip-gist",
        action="store_true",
        help="Write local bundle only; do not PATCH gist",
    )
    parser.add_argument(
        "--pin-bundle-only",
        action="store_true",
        help="Merge bundled T1 into gist/local without Gemini sweep",
    )
    return parser.parse_args()


# --- ORCHESTRATION ---
def main():
    args = parse_args()

    if args.dry_run:
        gist_prose, gist_compute = fetch_gist_catalogs() if GIST_TOKEN else ({}, {})
    else:
        _require_api_keys(needs_gemini=not args.pin_bundle_only)
        gist_prose, gist_compute = fetch_gist_catalogs()

    if args.pin_bundle_only:
        merged = merge_t1_pins(gist_compute)
        write_local_compute(merged)
        if not args.skip_gist and not args.dry_run:
            update_gist(prose_countries=gist_prose, compute_countries=merged)
        return
    progress = load_progress() if args.resume else {"done": [], "prose": {}, "compute": {}}

    prose_records = dict(gist_prose)
    prose_records.update(progress.get("prose", {}))
    compute_records = dict(gist_compute)
    compute_records.update(progress.get("compute", {}))

    codes = [c.upper() for c in args.codes] if args.codes else list(ISO_COUNTRIES)
    if args.resume:
        done = set(progress.get("done", [])) | (
            set(prose_records.keys()) & set(compute_records.keys())
        )
        codes = [c for c in codes if c not in done]

    if args.limit and args.limit > 0:
        codes = codes[: args.limit]

    total = len(codes)
    print(f"🌍 Processing {total} countries (prose + compute)...")
    prose_errors = 0
    compute_errors = 0
    processed = 0

    for index, code in enumerate(codes, 1):
        print(f"[{index}/{total}] {code}")

        if args.dry_run:
            processed += 1
            continue

        try:
            prose_records[code] = normalize_prose(code, gemini_prose_request(code))
        except Exception as exc:
            print(f"  ❌ prose failed: {exc}")
            prose_errors += 1

        time.sleep(REQUEST_SLEEP_SECONDS)

        try:
            compute_records[code] = normalize_compute(code, gemini_compute_request(code))
        except Exception as exc:
            print(f"  ❌ compute failed: {exc}")
            compute_errors += 1

        time.sleep(REQUEST_SLEEP_SECONDS)

        progress["done"] = sorted(set(progress.get("done", [])) | {code})
        progress["prose"] = prose_records
        progress["compute"] = compute_records
        save_progress(progress)
        processed += 1

    compute_records = merge_t1_pins(compute_records)

    print(
        f"\nDone. processed={processed}, prose={len(prose_records)} (errors {prose_errors}), "
        f"compute={len(compute_records)} (errors {compute_errors})"
    )

    if not prose_records and not compute_records:
        raise SystemExit("❌ Critical failure: no data retrieved.")

    if args.dry_run:
        print("Dry run — skipping local write and gist push.")
        return

    write_local_compute(compute_records)

    if not args.skip_gist:
        update_gist(
            prose_countries=prose_records,
            compute_countries=compute_records,
        )


if __name__ == "__main__":
    main()
