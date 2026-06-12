#!/usr/bin/env python3
"""Phase 10 — Studio hub metrics + project/region format strings."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "docs/localization/phase10-translations.json"

T: dict[str, tuple[str, str]] = {
    "%lld%% effective": ("%lld%% efectiva", "%lld%% efectiva"),
    "Burn %@/mo": ("Quema %@/mes", "Quema %@/mes"),
    "%lld invoices": ("%lld facturas", "%lld facturas"),
    "%lld awaiting": ("%lld pendientes", "%lld pendientes"),
    "Ended %@": ("Terminó %@", "Finalizó %@"),
    "%@/%@h": ("%1$@/%2$@ h", "%1$@/%2$@ h"),
    "Revisions: %lld/%lld": ("Revisiones: %lld/%lld", "Revisiones: %lld/%lld"),
    "%@/hr": ("%@/h", "%@/h"),
    "Lap %lld": ("Vuelta %lld", "Vuelta %lld"),
    "%@ · %@": ("%1$@ · %2$@", "%1$@ · %2$@"),
    "%@ typically uses %@.": ("%@ suele usar %@.", "%@ suele usar %@."),
    "%@ · typical %@": ("%@ · habitual %@", "%@ · habitual %@"),
    "English": ("English", "English"),
    "Spanish (Latin America)": ("Español (Latinoamérica)", "Español (Latinoamérica)"),
    "Spanish (Spain)": ("Español (España)", "Español (España)"),
    "This country": ("Este país", "Este país"),
    "a local currency": ("una moneda local", "una moneda local"),
}


def main() -> None:
    payload = {k: {"es-419": a, "es-ES": e} for k, (a, e) in T.items()}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} keys to {OUT}")


if __name__ == "__main__":
    main()
