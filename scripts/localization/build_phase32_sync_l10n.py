#!/usr/bin/env python3
"""Phase 32 — Entity-first iCloud sync + conflict center strings (en → es)."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/localization/phase32-sync-translations.json"
MERGE = ROOT / "scripts/localization/merge_phase1_translations.py"

T: dict[str, tuple[str, str]] = {
    "Review sync conflicts": ("Revisar conflictos de sincronización", "Revisar conflictos de sincronización"),
    "Sync conflicts": ("Conflictos de sincronización", "Conflictos de sincronización"),
    "Review conflicts": ("Revisar conflictos", "Revisar conflictos"),
    "No sync conflicts. Your iPhone and iPad data matches.": (
        "No hay conflictos de sincronización. Los datos de tu iPhone e iPad coinciden.",
        "No hay conflictos de sincronización. Los datos de tu iPhone e iPad coinciden.",
    ),
    "Keep this device": ("Conservar este dispositivo", "Conservar este dispositivo"),
    "Keep iCloud": ("Conservar iCloud", "Conservar iCloud"),
    "Settings conflict": ("Conflicto de ajustes", "Conflicto de ajustes"),
    "Budget settings conflict": ("Conflicto de ajustes de presupuesto", "Conflicto de ajustes de presupuesto"),
    "Appearance settings conflict": ("Conflicto de ajustes de apariencia", "Conflicto de ajustes de apariencia"),
    "Studio settings conflict": ("Conflicto de ajustes de Studio", "Conflicto de ajustes de Studio"),
    "Studio item conflict": ("Conflicto de elemento de Studio", "Conflicto de elemento de Studio"),
    "Simple Studio item conflict": (
        "Conflicto de elemento de Simple Studio",
        "Conflicto de elemento de Simple Studio",
    ),
    "Workspace conflict": ("Conflicto de espacio de trabajo", "Conflicto de espacio de trabajo"),
}


def main() -> None:
    payload = {k: {"es-419": v[0], "es-ES": v[1]} for k, v in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")
    subprocess.run([sys.executable, str(MERGE), str(OUT)], check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
