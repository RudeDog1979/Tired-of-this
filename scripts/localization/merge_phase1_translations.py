#!/usr/bin/env python3
"""Merge Phase 1 translations into BuxMuse/Localizable.xcstrings."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "BuxMuse/Localizable.xcstrings"
TRANSLATIONS = ROOT / "docs/localization/phase1-translations.json"


def es_units(value_419: str, value_es: str | None = None) -> dict:
    es = value_es or value_419
    return {
        "es": {"stringUnit": {"state": "translated", "value": es}},
        "es-419": {"stringUnit": {"state": "translated", "value": value_419}},
        "es-ES": {"stringUnit": {"state": "translated", "value": es}},
    }


def merge(translations: dict[str, dict]) -> tuple[int, int]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.setdefault("strings", {})
    applied = 0
    skipped = 0
    for key, locs in translations.items():
        if not key.strip():
            skipped += 1
            continue
        entry = strings.setdefault(key, {})
        existing = entry.get("localizations", {})
        merged = {**existing, **locs}
        entry["localizations"] = merged
        applied += 1
    CATALOG.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return applied, skipped


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else TRANSLATIONS
    if not path.is_file():
        print(f"Missing {path}", file=sys.stderr)
        sys.exit(1)
    raw = json.loads(path.read_text(encoding="utf-8"))
    # Accept {"Key": {"es-419": "...", "es-ES": "..."}} or pre-built localization blocks
    normalized: dict[str, dict] = {}
    for key, value in raw.items():
        if "localizations" in value:
            normalized[key] = value["localizations"]
        elif "es-419" in value:
            normalized[key] = es_units(value["es-419"], value.get("es-ES"))
        else:
            normalized[key] = value
    applied, skipped = merge(normalized)
    print(f"Merged {applied} keys into {CATALOG} (skipped {skipped})")


if __name__ == "__main__":
    main()
