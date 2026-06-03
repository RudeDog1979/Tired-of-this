#!/usr/bin/env python3
"""Extract UI string keys from all BuxMuse Swift sources (Phase 8 full-app audit)."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUXMUSE = ROOT / "BuxMuse"
CATALOG = ROOT / "BuxMuse/Localizable.xcstrings"

PATTERNS = [
    re.compile(r'Text\(\s*"([^"]+)"'),
    re.compile(r'BuxCatalogText\.text\(\s*"([^"]+)"'),
    re.compile(r'navigationTitle\(\s*"([^"]+)"'),
    re.compile(r'Label\(\s*"([^"]+)"'),
    re.compile(r'Button\(\s*"([^"]+)"'),
    re.compile(r'BuxSectionHeader\(title:\s*"([^"]+)"'),
    re.compile(r'BuxFormSection\(title:\s*"([^"]+)"'),
    re.compile(r'BuxButton\(\s*\n?\s*title:\s*"([^"]+)"'),
    re.compile(r'Section\(\s*"([^"]+)"'),
    re.compile(r'accessibilityLabel:\s*"([^"]+)"'),
    re.compile(r'Picker\(\s*"([^"]+)"'),
    re.compile(r'\.confirmationDialog\(\s*\n?\s*"([^"]+)"'),
    re.compile(r'\.alert\(\s*"([^"]+)"'),
    re.compile(r'prompt:\s*Text\(\s*"([^"]+)"'),
    re.compile(r'placeholder:\s*"([^"]+)"'),
    re.compile(r'LocalizedStringKey\(stringLiteral:\s*"([^"]+)"'),
]

SKIP_SUBSTR = ("#RRGGBB", "http://", "https://", "BM-", "v1.0.0", "file://")
SKIP_EXACT = {"On", "Off", "OK", "PRO", "FREE", "Studio", "BuxMuse", "Aa", "mi", "tudio"}


def should_skip(value: str) -> bool:
    if len(value) < 2 or value in SKIP_EXACT:
        return True
    if value.startswith("+\\(") or ("\\(" in value and "%" not in value):
        return True
    for sub in SKIP_SUBSTR:
        if sub in value:
            return True
    if re.fullmatch(r"[A-Z0-9_]+", value):
        return True
    if re.fullmatch(r"[\d.$#%+·◆•\s₿-]+", value):
        return True
    return False


def collect() -> list[str]:
    keys: set[str] = set()
    for path in BUXMUSE.rglob("*.swift"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern in PATTERNS:
            for match in pattern.finditer(text):
                value = match.group(1).strip()
                if not should_skip(value):
                    keys.add(value)
    # Transaction categories + dashboard pills (dynamic Text paths)
    for cat in (
        "Groceries",
        "Restaurants",
        "Transport",
        "Subscriptions",
        "Housing",
        "Entertainment",
        "Shopping",
        "Health",
        "Utilities",
        "Travel",
        "Education",
        "Personal",
        "Income",
        "Other",
    ):
        keys.add(cat)
    for pill in ("Expenses", "Subscriptions", "Goals", "Insights", "Money Map"):
        keys.add(pill)
    for mode in ("Simple", "Envelope", "Custom"):
        keys.add(mode)
    for theme in (
        "Standard", "Bux", "Ocean", "Sunset", "Emerald", "Sakura", "Gold",
        "Crimson", "Horizon", "Quantum", "Galactic", "Titanium", "Abyssal",
    ):
        keys.add(theme)
    for accent in (
        "Blue", "Green", "Orange", "Pink", "Purple", "Red", "Teal",
        "Indigo", "Mint", "Cyan", "Yellow",
    ):
        keys.add(accent)
    return sorted(keys)


def main() -> None:
    keys = collect()
    out = ROOT / "docs/localization/phase8-keys.txt"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(keys) + "\n", encoding="utf-8")

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = catalog.setdefault("strings", {})
    new_keys = [k for k in keys if k not in strings]
    for k in new_keys:
        strings[k] = {}
    if new_keys:
        CATALOG.write_text(
            json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

    print(f"Wrote {len(keys)} keys to {out}")
    print(f"Added {len(new_keys)} new keys to catalog")


if __name__ == "__main__":
    main()
