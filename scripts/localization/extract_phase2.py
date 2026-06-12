#!/usr/bin/env python3
"""Extract Phase 2 UI strings (Studio hub + Business Card / Bux Canvas)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUXMUSE = ROOT / "BuxMuse"

PHASE2_DIRS = [
    BUXMUSE / "Features/Studio/Views",
    BUXMUSE / "Features/Studio/Simple/Views",
    BUXMUSE / "Features/Studio/BusinessCard",
    BUXMUSE / "Features/Studio/Planner",
]

PATTERNS = [
    re.compile(r'Text\(\s*"([^"]+)"'),
    re.compile(r'navigationTitle\(\s*"([^"]+)"'),
    re.compile(r'Label\(\s*"([^"]+)"'),
    re.compile(r'Button\(\s*"([^"]+)"'),
    re.compile(r'BuxSectionHeader\(title:\s*"([^"]+)"'),
    re.compile(r'BuxButton\(\s*\n?\s*title:\s*"([^"]+)"'),
    re.compile(r'BuxCenteredTopBar\(title:\s*"([^"]+)"'),
    re.compile(r'previewActionButton\(title:\s*"([^"]+)"'),
    re.compile(r'accessibilityLabel:\s*"([^"]+)"'),
    re.compile(r'title:\s*"([^"]+)"'),
]

SKIP_SUBSTR = ("#", "%@", "%lld", "%1$", "http", "BM-")
SKIP_EXACT = {"On", "Off", "Any", "New", "PRO", "OK", "Studio", "Bux Canvas"}


def should_skip(value: str) -> bool:
    if len(value) < 2 or value in SKIP_EXACT:
        return True
    if "\\(" in value:
        return True
    for sub in SKIP_SUBSTR:
        if sub in value:
            return True
    return False


def main() -> None:
    keys: set[str] = set()
    for directory in PHASE2_DIRS:
        for path in directory.rglob("*.swift"):
            text = path.read_text(encoding="utf-8", errors="ignore")
            for pattern in PATTERNS:
                for match in pattern.finditer(text):
                    value = match.group(1).strip()
                    if not should_skip(value):
                        keys.add(value)
    out = ROOT / "docs/localization/phase2-keys.txt"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(sorted(keys)) + "\n", encoding="utf-8")
    print(f"Wrote {len(keys)} keys to {out}")


if __name__ == "__main__":
    main()
