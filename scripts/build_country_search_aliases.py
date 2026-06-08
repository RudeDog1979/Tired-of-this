#!/usr/bin/env python3
"""Generate country_search_aliases.json from Apple CLDR region names + extras.

Batch 1 = first half of sorted ISO codes (A…); batch 2 = remainder.
Does not touch tax JSON.
"""

from __future__ import annotations

import json
import re
import subprocess
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "BuxMuse/Resources/country_search_aliases.json"

LOCALES = ["en", "es", "es-419", "es-ES", "fr", "de", "pt", "it", "pl", "ru", "ar", "zh-Hans"]

# High-value extras beyond CLDR (abbreviations, colloquial, cross-language).
EXTRA_ALIASES: dict[str, list[str]] = {
    "US": ["usa", "u.s.", "u.s.a.", "eeuu", "e.u.u.", "estados unidos", "united states of america"],
    "DO": ["rd", "rep dom", "rep. dom.", "dominicana", "dominican", "republica dominicana"],
    "GB": ["uk", "u.k.", "britain", "great britain", "england", "reino unido", "royaume-uni"],
    "UK": ["gb", "uk", "britain", "great britain", "england"],
    "MX": ["méxico", "mexico", "méjico"],
    "ES": ["espana", "españa", "spain"],
    "PR": ["puerto rico", "borinquen"],
    "AR": ["argentina"],
    "CO": ["colombia"],
    "VE": ["venezuela"],
    "CL": ["chile"],
    "PE": ["peru", "perú"],
    "EC": ["ecuador"],
    "GT": ["guatemala"],
    "HN": ["honduras"],
    "SV": ["el salvador", "salvador"],
    "NI": ["nicaragua"],
    "CR": ["costa rica"],
    "PA": ["panama", "panamá"],
    "CU": ["cuba"],
    "BO": ["bolivia"],
    "PY": ["paraguay"],
    "UY": ["uruguay"],
    "BR": ["brasil", "brazil"],
    "CA": ["canada", "canadá"],
    "AU": ["australia"],
    "NZ": ["new zealand", "nueva zelanda"],
    "IN": ["india", "bharat"],
    "CN": ["china", "prc"],
    "JP": ["japan", "nippon"],
    "KR": ["korea", "south korea", "republic of korea"],
    "DE": ["deutschland", "germany", "alemania"],
    "FR": ["france", "francia"],
    "IT": ["italy", "italia"],
    "NL": ["holland", "netherlands", "nederland", "paises bajos"],
    "BE": ["belgium", "belgica", "belgique"],
    "CH": ["switzerland", "suiza", "schweiz"],
    "AT": ["austria", "osterreich", "österreich"],
    "IE": ["ireland", "eire"],
    "PT": ["portugal"],
    "PL": ["poland", "polska"],
    "RU": ["russia", "rossiya"],
    "UA": ["ukraine", "ukraina"],
    "TR": ["turkey", "turkiye", "türkiye"],
    "SA": ["ksa", "saudi"],
    "AE": ["uae", "emirates"],
    "IL": ["israel"],
    "ZA": ["south africa", "sudafrica"],
    "NG": ["nigeria"],
    "EG": ["egypt", "egipto"],
    "KE": ["kenya"],
    "PH": ["philippines", "filipinas"],
    "TH": ["thailand", "tailandia"],
    "VN": ["vietnam", "viet nam"],
    "ID": ["indonesia"],
    "MY": ["malaysia"],
    "SG": ["singapore", "singapur"],
    "HK": ["hong kong"],
    "TW": ["taiwan"],
    "GR": ["greece", "grecia", "hellas"],
    "EL": ["gr", "greece", "grecia"],
    "SE": ["sweden", "suecia", "sverige"],
    "NO": ["norway", "noruega", "norge"],
    "DK": ["denmark", "dinamarca", "danmark"],
    "FI": ["finland", "finlandia", "suomi"],
    "CZ": ["czech", "czechia", "chequia"],
    "HU": ["hungary", "hungria", "magyarorszag"],
    "RO": ["romania", "rumania"],
    "BG": ["bulgaria"],
    "HR": ["croatia", "croacia"],
    "RS": ["serbia"],
    "SK": ["slovakia", "eslovaquia"],
    "SI": ["slovenia", "eslovenia"],
    "LT": ["lithuania", "lituania"],
    "LV": ["latvia", "letonia"],
    "EE": ["estonia"],
    "IS": ["iceland", "islandia"],
    "LU": ["luxembourg", "luxemburgo"],
    "MT": ["malta"],
    "CY": ["cyprus", "chipre"],
    "PK": ["pakistan"],
    "BD": ["bangladesh"],
    "LK": ["sri lanka", "ceylon"],
    "NP": ["nepal"],
    "MM": ["myanmar", "burma"],
    "KH": ["cambodia", "camboya"],
    "LA": ["laos"],
    "KZ": ["kazakhstan"],
    "UZ": ["uzbekistan"],
    "QA": ["qatar"],
    "KW": ["kuwait"],
    "BH": ["bahrain"],
    "OM": ["oman"],
    "JO": ["jordan", "jordania"],
    "LB": ["lebanon", "libano"],
    "IQ": ["iraq", "irak"],
    "IR": ["iran"],
    "AF": ["afghanistan"],
    "MA": ["morocco", "marruecos", "maroc"],
    "DZ": ["algeria", "argelia"],
    "TN": ["tunisia", "tunez"],
    "LY": ["libya", "libia"],
    "ET": ["ethiopia", "etiopia"],
    "GH": ["ghana"],
    "CI": ["ivory coast", "cote d'ivoire", "côte d'ivoire"],
    "SN": ["senegal"],
    "CM": ["cameroon", "camerun"],
    "AO": ["angola"],
    "MZ": ["mozambique"],
    "ZW": ["zimbabwe", "zimbabue"],
    "JM": ["jamaica"],
    "HT": ["haiti"],
    "TT": ["trinidad", "tobago"],
    "BB": ["barbados"],
    "BS": ["bahamas"],
    "BZ": ["belize"],
    "GY": ["guyana"],
    "SR": ["suriname"],
    "FJ": ["fiji"],
    "PG": ["papua new guinea"],
}


def fold_ascii(text: str) -> str:
    normalized = unicodedata.normalize("NFD", text)
    return "".join(c for c in normalized if unicodedata.category(c) != "Mn").lower()


def swift_region_dump() -> dict[str, dict[str, str]]:
    swift = r'''
import Foundation
let locales = ["en", "es", "es-419", "es-ES", "fr", "de", "pt", "it", "pl", "ru", "ar", "zh-Hans"]
let codes = Locale.Region.isoRegions.filter { $0.identifier.count == 2 }.map { $0.identifier }.sorted()
var out: [[String: Any]] = []
for code in codes {
    var names: [String: String] = [:]
    for lid in locales {
        let loc = Locale(identifier: lid)
        if let n = loc.localizedString(forRegionCode: code), !n.isEmpty, n.uppercased() != code {
            names[lid] = n
        }
    }
    out.append(["code": code, "names": names])
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
'''
    raw = subprocess.check_output(["swift", "-e", swift], text=True)
    rows = json.loads(raw)
    return {row["code"]: row["names"] for row in rows}


def build_terms(code: str, names: dict[str, str]) -> list[str]:
    terms: set[str] = set()
    terms.add(code.lower())
    for name in names.values():
        low = name.strip().lower()
        if low:
            terms.add(low)
            terms.add(fold_ascii(low))
    for extra in EXTRA_ALIASES.get(code, []):
        low = extra.strip().lower()
        if low:
            terms.add(low)
            terms.add(fold_ascii(low))
    # UK resolves to GB in app
    if code == "GB":
        for extra in EXTRA_ALIASES.get("UK", []):
            low = extra.strip().lower()
            if low:
                terms.add(low)
                terms.add(fold_ascii(low))
    return sorted(terms)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=int, choices=[1, 2, 0], default=0, help="1=first half, 2=second half, 0=all")
    args = parser.parse_args()

    dump = swift_region_dump()
    codes = sorted(dump.keys())
    midpoint = len(codes) // 2
    if args.batch == 1:
        selected = codes[:midpoint]
    elif args.batch == 2:
        selected = codes[midpoint:]
    else:
        selected = codes

    countries: dict[str, list[str]] = {}
    for code in selected:
        countries[code] = build_terms(code, dump[code])

    existing: dict = {}
    if OUT.exists() and args.batch == 2:
        existing = json.loads(OUT.read_text(encoding="utf-8"))
        existing_countries = existing.get("countries", {})
        existing_countries.update(countries)
        countries = existing_countries
        batch_note = 2
        complete = True
    elif args.batch == 1:
        batch_note = 1
        complete = False
    else:
        batch_note = 0
        complete = True

    payload = {
        "version": 1,
        "batch": batch_note,
        "complete": complete,
        "totalRegions": len(codes),
        "includedRegions": len(countries),
        "countries": dict(sorted(countries.items())),
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} — {len(countries)} regions (batch={batch_note}, complete={complete})")


if __name__ == "__main__":
    main()
