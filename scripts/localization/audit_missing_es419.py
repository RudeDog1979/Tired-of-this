#!/usr/bin/env python3
"""List catalog keys used in Swift that lack es-419 translations."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "BuxMuse/Localizable.xcstrings"
EXTRACT = ROOT / "scripts/localization/extract_phase8.py"


def main() -> None:
    proc = subprocess.run(
        [sys.executable, str(EXTRACT)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    keys = set()
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            keys.add(line)

    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.get("strings", {})
    missing = []
    for key in sorted(keys):
        entry = strings.get(key, {})
        locs = entry.get("localizations", {})
        es = locs.get("es-419", {}).get("stringUnit", {}).get("value")
        if not es:
            missing.append(key)

    out = ROOT / "docs/localization/phase20-missing-es419.txt"
    out.write_text("\n".join(missing) + "\n", encoding="utf-8")
    print(f"{len(missing)} keys missing es-419 → {out}")


if __name__ == "__main__":
    main()
