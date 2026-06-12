#!/usr/bin/env python3
"""Extract Phase 1 UI string keys from shell Swift sources."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUXMUSE = ROOT / "BuxMuse"

PHASE1_DIRS = [
    BUXMUSE / "Features/Settings",
    BUXMUSE / "Features/Dashboard",
    BUXMUSE / "Features/ExpenseInput",
]

EXTRA_FILES = [
    BUXMUSE / "Core/App/RootView.swift",
    BUXMUSE / "Core/DesignSystem/BuxComponents.swift",
    BUXMUSE / "Core/DesignSystem/BuxFormScaffold.swift",
    BUXMUSE / "Core/DesignSystem/HustleSelectorBar.swift",
]

PATTERNS = [
    re.compile(r'Text\(\s*"([^"]+)"'),
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
    re.compile(r'title:\s*"([^"]+)"'),
    re.compile(r'subtitle:\s*"([^"]+)"'),
]

SKIP_SUBSTR = ("#", "%@", "%lld", "%1$", "http", "BM-", "v1.0.0")
SKIP_EXACT = {"On", "Off", "Any", "New", "PRO", "OK", "FREE", "Studio"}


def should_skip(value: str) -> bool:
    if len(value) < 2 or value in SKIP_EXACT:
        return True
    if value.startswith("+\\(") or "\\(" in value:
        return True
    for sub in SKIP_SUBSTR:
        if sub in value:
            return True
    if re.fullmatch(r"[A-Z0-9_]+", value):
        return True
    return False


def collect() -> list[str]:
    files: list[Path] = list(EXTRA_FILES)
    for directory in PHASE1_DIRS:
        files.extend(directory.rglob("*.swift"))

    keys: set[str] = set()
    for path in files:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern in PATTERNS:
            for match in pattern.finditer(text):
                value = match.group(1).strip()
                if not should_skip(value):
                    keys.add(value)
    return sorted(keys)


def main() -> None:
    keys = collect()
    out = ROOT / "docs/localization/phase1-keys.txt"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(keys) + "\n", encoding="utf-8")
    print(f"Wrote {len(keys)} keys to {out}")


if __name__ == "__main__":
    main()
