#!/usr/bin/env python3
"""Replace static Text(\"Key\") with BuxCatalogDynamicText(key: \"Key\") in Swift UI files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUXMUSE = ROOT / "BuxMuse"

# Directories to sweep (user-facing settings + dashboard + expenses + goals)
TARGET_DIRS = [
    BUXMUSE / "Features",
    BUXMUSE / "Components",
    BUXMUSE / "Core" / "DesignSystem",
    BUXMUSE / "Core" / "UI",
    BUXMUSE / "Core" / "Security",
]

PATTERN = re.compile(r'\bText\(\s*"([^"\\]+)"\s*\)')

# Skip files/patterns where Text type is required (Canvas resolve, TextField prompt, etc.)
SKIP_PATH_PARTS = ("StudioUnlockAnimationView.swift",)

SKIP_SUBSTR = ("#", "http", "BM-", "\\(", "%lld", "%@", "%.f", "PRO")


def should_replace(key: str) -> bool:
    if len(key) < 2:
        return False
    for sub in SKIP_SUBSTR:
        if sub in key:
            return False
    if key.isupper() and len(key) <= 4:
        return False
    return True


def process_file(path: Path) -> int:
    if any(part in path.name for part in SKIP_PATH_PARTS):
        return 0
    text = path.read_text(encoding="utf-8")
    count = 0

    def repl(m: re.Match) -> str:
        nonlocal count
        key = m.group(1)
        if not should_replace(key):
            return m.group(0)
        count += 1
        return f'BuxCatalogDynamicText(key: "{key}")'

    new_text = PATTERN.sub(repl, text)
    if count and new_text != text:
        path.write_text(new_text, encoding="utf-8")
    return count


def main() -> None:
    total = 0
    files = 0
    for base in TARGET_DIRS:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.swift")):
            n = process_file(path)
            if n:
                print(f"{path.relative_to(ROOT)}: {n}")
                total += n
                files += 1
    print(f"Replaced {total} literals in {files} files")


if __name__ == "__main__":
    main()
