#!/usr/bin/env python3
"""
Generates BuxMuse/Resources/buxmuse_country_map.json

Maps every ISO 3166-1 alpha-2 territory → content locale key in buxmuse_news.json.
Gemini generates ONE block per locale (ES, PT, FR…), not per country.

Run: python3 scripts/generate_country_map.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "BuxMuse" / "Resources" / "buxmuse_country_map.json"

# Content locales Gemini / buxmuse_news.json must provide
CONTENT_LOCALES = [
    "ES", "PL", "FR", "DE", "PT", "IT", "NL", "SE", "NO", "DK", "FI",
    "RU", "UA", "TR", "JP", "KR", "CN", "AE", "IN", "US", "DEFAULT",
]

LOCALE_LANGUAGE = {
    "ES": "Spanish",
    "PL": "Polish",
    "FR": "French",
    "DE": "German",
    "PT": "Portuguese",
    "IT": "Italian",
    "NL": "Dutch",
    "SE": "Swedish",
    "NO": "Norwegian",
    "DK": "Danish",
    "FI": "Finnish",
    "RU": "Russian",
    "UA": "Ukrainian",
    "TR": "Turkish",
    "JP": "Japanese",
    "KR": "Korean",
    "CN": "Chinese (Simplified)",
    "AE": "Arabic",
    "IN": "Hindi",
    "US": "English (US)",
    "DEFAULT": "English (International)",
}


def assign(map_: dict[str, str], codes: list[str], locale: str) -> None:
    for code in codes:
        map_[code.upper()] = locale


def build_country_map() -> dict[str, str]:
    m: dict[str, str] = {}

    # ── Spanish ──
    assign(m, [
        "ES", "MX", "AR", "CO", "CL", "PE", "VE", "EC", "GT", "CU", "BO", "DO", "HN", "PY",
        "SV", "NI", "CR", "PA", "UY", "PR", "GQ", "AD", "BZ", "IC",  # IC = Canary via ES
    ], "ES")

    # ── Portuguese ──
    assign(m, ["PT", "BR", "AO", "MZ", "CV", "GW", "ST", "TL", "MO"], "PT")

    # ── French ──
    assign(m, [
        "FR", "MC", "HT", "SN", "CI", "ML", "BF", "NE", "TG", "BJ", "GN", "CD", "CG", "GA",
        "CM", "MG", "RW", "BI", "DJ", "KM", "CF", "TD", "VU", "NC", "PF", "GF", "GP", "MQ",
        "RE", "YT", "PM", "WF", "BL", "MF", "LU", "BE",
    ], "FR")

    # ── German ──
    assign(m, ["DE", "AT", "LI", "CH"], "DE")

    # ── Italian ──
    assign(m, ["IT", "SM", "VA"], "IT")

    # ── Dutch ──
    assign(m, ["NL", "AW", "CW", "SX", "BQ", "SR"], "NL")

    # ── Nordic / Baltic singles ──
    assign(m, ["PL"], "PL")
    assign(m, ["SE", "AX"], "SE")
    assign(m, ["NO", "SJ", "BV"], "NO")
    assign(m, ["DK", "FO", "GL"], "DK")
    assign(m, ["FI"], "FI")
    assign(m, ["IS"], "NO")  # closest Nordic locale in feed

    # ── Cyrillic / Eastern Europe ──
    assign(m, ["RU", "BY", "KZ", "KG"], "RU")
    assign(m, ["UA", "MD"], "UA")

    # ── Turkish ──
    assign(m, ["TR", "CY"], "TR")

    # ── East Asia ──
    assign(m, ["JP"], "JP")
    assign(m, ["KR", "KP"], "KR")
    assign(m, ["CN"], "CN")
    assign(m, ["TW", "HK", "MO"], "CN")

    # ── Arabic ──
    assign(m, [
        "AE", "SA", "QA", "KW", "BH", "OM", "YE", "IQ", "JO", "LB", "SY", "PS", "EG", "LY",
        "TN", "DZ", "MA", "SD", "SO", "MR", "EH", "COM",  # COM invalid - remove
    ], "AE")
    m.pop("COM", None)

    # ── Hindi / India ──
    assign(m, ["IN"], "IN")

    # ── English US ──
    assign(m, [
        "US", "UM", "VI", "GU", "AS", "MP", "FM", "MH", "PW", "PR",  # PR Spanish - fix below
        "LR", "SL", "GM", "GH", "NG", "KE", "UG", "TZ", "ZW", "ZM", "MW", "BW", "NA", "SZ",
        "LS", "SS", "PK", "PH", "SG", "MY", "BN", "FJ", "PG", "SB", "WS", "TO", "KI", "NR",
        "TV", "CK", "NU", "TK", "NF", "CX", "CC", "HM", "AQ", "IO", "SH", "PN", "GS", "FK",
        "MS", "TC", "VG", "AI", "AG", "BB", "BS", "BM", "KY", "GD", "JM", "KN", "LC", "VC",
        "TT", "DM", "JE", "GG", "IM", "MT", "CY", "IL", "SC", "MU", "MV", "NP", "BT", "LK",
        "MM", "KH", "LA", "ID", "TH", "VN", "KH", "TL", "TL", "BN", "BN",
    ], "US")

    # Fixes: territories with stronger non-English mapping
    for code, locale in {
        "PR": "ES", "DO": "ES", "GQ": "ES", "BZ": "ES", "GY": "NL", "SR": "NL",
        "MO": "CN", "TL": "PT", "ST": "PT", "CV": "PT", "AO": "PT", "MZ": "PT",
        "CY": "TR", "IL": "DEFAULT", "PK": "DEFAULT", "BD": "DEFAULT", "LK": "DEFAULT",
        "MM": "DEFAULT", "KH": "DEFAULT", "LA": "DEFAULT", "ID": "DEFAULT", "TH": "DEFAULT",
        "VN": "DEFAULT", "PH": "US", "SG": "US", "MY": "DEFAULT", "BN": "DEFAULT",
        "DM": "US",  # Dominica (English) not DO
        "CH": "DE", "BE": "FR", "LU": "FR", "CA": "DEFAULT",
    }.items():
        m[code] = locale

    # ── English DEFAULT (Commonwealth / UK voice) ──
    assign(m, ["GB", "UK", "IE", "AU", "NZ", "ZA", "CA"], "DEFAULT")

    # Re-apply critical overrides after DEFAULT batch
    m["IN"] = "IN"
    m["DO"] = "ES"
    m["BR"] = "PT"
    m["PT"] = "PT"

    return m


def all_iso_territories() -> list[str]:
    try:
        import pycountry  # type: ignore
        return sorted({c.alpha_2 for c in pycountry.countries})
    except ImportError:
        pass

    # Fallback: ISO list from Locale if pycountry missing (macOS Python)
    import subprocess
    result = subprocess.run(
        ["swift", "-e", """
import Foundation
let codes = Locale.Region.isoRegions
    .filter { $0.subRegions.isEmpty }
    .map { $0.identifier }
print(",".join(sorted(codes)))
"""],
        capture_output=True, text=True, cwd=ROOT)
    if result.returncode == 0 and result.stdout.strip():
        return [c.strip() for c in result.stdout.strip().split(",") if len(c.strip()) == 2]

    # Minimal fallback
    return sorted(set(build_country_map().keys()))


def main() -> None:
    explicit = build_country_map()
    all_codes = all_iso_territories()

    countries: dict[str, str] = {}
    unmapped: list[str] = []

    for code in all_codes:
        upper = code.upper()
        if upper in explicit:
            countries[upper] = explicit[upper]
        else:
            unmapped.append(upper)

    # Unmapped → DEFAULT (English international) until you add a locale to Gemini
    for code in unmapped:
        countries[code] = "DEFAULT"

    payload = {
        "version": 1,
        "description": "ISO 3166-1 alpha-2 country/territory → buxmuse_news.json locale key",
        "contentLocales": CONTENT_LOCALES,
        "localeLanguages": LOCALE_LANGUAGE,
        "countries": dict(sorted(countries.items())),
        "stats": {
            "totalTerritories": len(countries),
            "explicitlyMapped": len(explicit),
            "defaultFallback": len(unmapped),
        },
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"✅ Wrote {OUT}")
    print(f"   Territories: {len(countries)}")
    print(f"   Explicit:    {len(explicit)}")
    print(f"   → DEFAULT:   {len(unmapped)}")
    if unmapped:
        print(f"   Unmapped codes (now DEFAULT): {', '.join(unmapped[:20])}{'…' if len(unmapped) > 20 else ''}")


if __name__ == "__main__":
    main()
